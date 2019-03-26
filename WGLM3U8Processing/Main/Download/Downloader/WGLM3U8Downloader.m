//
//  WGLM3U8Downloader.m
//  WGLM3U8DownloadProvider
//
//  Created by wugl on 2018/12/21.
//  Copyright © 2018年 WGLKit. All rights reserved.
//

#define kKeepDiskSpace      (20)      //预留给用户的磁盘缓存空间大小20MB
static const double kBufferSize = (1); //每下载1 MB数据则写一次磁盘

#import "WGLM3U8Downloader.h"
#import <CommonCrypto/CommonDigest.h>

@interface WGLM3U8Downloader ()
@property (nonatomic, copy) NSString *downloadFilePath;     //下载文件的存放路径
@property (nonatomic, assign) uint64_t downloadFileSize;
@property (nonatomic, assign) WGLDownloadState downloadState;
@property (nonatomic, copy) NSString *downloadDirectory;    //下载文件的存放目录
@property (nonatomic, copy) NSString *defaultDirectory;     //默认下载目录NSTemporaryDirectory()
@property (nonatomic, copy) NSString *defaultFilePath;      //默认下载路径
@property (nonatomic, copy) NSString *cacheFileName;        //文件缓存名
@property (nonatomic, copy) NSString *tempDownloadDirectory;    //临时下载目录
@property (nonatomic, copy) NSString *tempDownloadFilePath;     //临时下载路径

@property (nonatomic, strong) NSMutableURLRequest *request;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *receiveData;
@property (nonatomic, assign) uint64_t expectedDataLength;
@property (nonatomic, assign) uint64_t receivedDataLength;
@property (nonatomic, strong) NSFileHandle *fileHandle;


@end

@implementation WGLM3U8Downloader

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (void)start {
    if (self.downloadState == WGLDownloadStateDownloading) {
        //已经处在下载中状态
        return;
    }
    
    //先清除旧的下载
    [self cancel];
    
    //下载准备
    [self prepare];
    
    self.downloadState = WGLDownloadStateDownloading;
    self.receiveData = [[NSMutableData alloc] init];
    
    //开始新的下载
    [self performSelector:@selector(startConnection)
                 onThread:[self.class _networkThread]
               withObject:nil
            waitUntilDone:NO];
}

- (void)startConnection {
    if (self.urlString.length == 0) {
        return;
    }
    self.request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.urlString]];
    
    //Invalid URL
    if (![NSURLConnection canHandleRequest:self.request]) {
        if ([self.delegate respondsToSelector:@selector(downloadDidFail:errorType:)]) {
            [self.delegate downloadDidFail:self errorType:WGLM3U8DownloadErrorTypeInvalidURL];
        }
        [self cancel];
        return;
    }
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:(id<NSURLConnectionDelegate>)self startImmediately:NO];
    [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.connection start];
    
}

- (void)cancel {
    if (self.connection
        && self.downloadState == WGLDownloadStateDownloading) {
        //正处于下载中状态，则取消下载
        [self.connection cancel];
    }
    self.downloadState = WGLDownloadStateCancelled;
    self.receiveData = nil;
    self.connection = nil;
}

//下载准备
- (void)prepare {
    
    //目录不存在，则创建
    [self createDiretory];
    
    //文件不存在，则创建
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExist = [fileManager fileExistsAtPath:self.tempDownloadFilePath];
    if (!fileExist) {
        BOOL success = [fileManager createFileAtPath:self.tempDownloadFilePath contents:nil attributes:nil];
        if (NO == success) {
            NSLog(@"Create tmp filePath Failed.");
        }
        
        //是否设定了下载范围
        if (self.toByte > self.fromByte) {
            NSString *range = [NSString stringWithFormat:@"bytes=%lld-%lld", self.fromByte, self.toByte];
            [self.request setValue:range forHTTPHeaderField:@"Range"];
        }
    }
    else {
        //文件已存在，则断点续传下载
        
        uint64_t existFileSize = [self getFileSizeFromPath:self.tempDownloadFilePath];
        if (existFileSize > self.fromByte
            && existFileSize < self.toByte) {
            NSString *range = [NSString stringWithFormat:@"bytes=%lld-%lld", existFileSize, self.toByte];
            [self.request setValue:range forHTTPHeaderField:@"Range"];
        }
        else if (self.toByte > self.fromByte) {
            NSString *range = [NSString stringWithFormat:@"bytes=%lld-%lld", self.fromByte, self.toByte];
            [self.request setValue:range forHTTPHeaderField:@"Range"];
        }
        
        self.receivedDataLength += existFileSize;
    }
}

- (void)createDiretory {
    //创建下载目录
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:self.downloadDirectory isDirectory:&isDir];
    if(!(isDirExist && isDir)) {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:self.downloadDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"Create Directory Failed.");
        }
    }
    
    //创建下载临时目录
    BOOL isDir2 = FALSE;
    BOOL isDirExist2 = [fileManager fileExistsAtPath:self.tempDownloadDirectory isDirectory:&isDir2];
    if(!(isDirExist2 && isDir2)) {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:self.tempDownloadDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"Create temp Directory Failed.");
        }
    }
}

#pragma mark - Global network thread

//Global request network thread, used by NSURLConnection delegate.
+ (NSThread *)_networkThread {
    static NSThread *thread = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(_networkThreadMain:) object:nil];
        if ([thread respondsToSelector:@selector(setQualityOfService:)]) {
            thread.qualityOfService = NSQualityOfServiceBackground;
        }
        [thread start];
    });
    return thread;
}

//Network thread entry point.
+ (void)_networkThreadMain:(id)object {
    //开启常驻线程，否则在子线程启动NSURLConnection，子线程销毁了，导致不执行delegate回调
    @autoreleasepool {
        [[NSThread currentThread] setName:@"com.wugl.download.request"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
    uint64_t expectedContentLen = [response expectedContentLength];
    if ([response expectedContentLength] == NSURLResponseUnknownLength) {
        //文件已压缩，无法获取长度，会返回-1
        expectedContentLen = 0;
    }
    
    //文件总长度=已下载的长度（断点下载的情况下>0）+此次预期下载的长度
    self.expectedDataLength = self.receivedDataLength + expectedContentLen;
    
    //检测下载是否合法
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode >= 400) {
        self.downloadState = WGLDownloadStateFailed;
        
        if (httpResponse.statusCode == 416) {
            //1、断点下载的请求范围有问题，则选择删除本地缓存，下次取消断点下载
            
            if ([self.delegate respondsToSelector:@selector(downloadDidFail:errorType:)]) {
                [self.delegate downloadDidFail:self errorType:WGLM3U8DownloadErrorTypeInvalidRequestRange];
            }
        }
        else {
            //2、HTTP error
            
            if ([self.delegate respondsToSelector:@selector(downloadDidFail:errorType:)]) {
                [self.delegate downloadDidFail:self errorType:WGLM3U8DownloadErrorTypeHTTPError];
            }
        }
        
        [self cancel];
    }
    else {
        
        long long expected = @(self.expectedDataLength).longLongValue;
        uint64_t freeDiskSpace = [self getDiskFreeSpace];
        if (freeDiskSpace < kKeepDiskSpace
            || (freeDiskSpace < expected + kKeepDiskSpace && expected != NSURLResponseUnknownLength)) {
            //3、Not Enough free space
            
            self.downloadState = WGLDownloadStateFailed;
            
            if ([self.delegate respondsToSelector:@selector(downloadDidFail:errorType:)]) {
                [self.delegate downloadDidFail:self errorType:WGLM3U8DownloadErrorTypeNotEnoughFreeSpace];
            }
            [self cancel];
        }
        else {
            //开始下载
            
            self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempDownloadFilePath];
            [self caculateDownloadFileSize];
            
            if ([self.delegate respondsToSelector:@selector(downloadDidStart:)]) {
                [self.delegate downloadDidStart:self];
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    if (self.downloadState == WGLDownloadStateFailed
        || self.downloadState == WGLDownloadStateCancelled) {
        return;
    }
    
    [self.receiveData appendData:data];
    self.receivedDataLength += data.length;
    
    //每下载完1MB则写入一次磁盘
    uint64_t hasReceivedLength = self.receiveData.length / 1024 / 1024;
    if (hasReceivedLength > kBufferSize) {
        [self.fileHandle writeData:self.receiveData];
        self.receiveData.data = [NSData data];
    }
    
    if ([self.delegate respondsToSelector:@selector(downloader:didReceiveLength:totalLength:)]) {
        [self.delegate downloader:self didReceiveLength:self.receivedDataLength totalLength:self.expectedDataLength];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    if (self.downloadState == WGLDownloadStateDownloading) {
        self.downloadState = WGLDownloadStateFinish;
        
        [self.fileHandle writeData:self.receiveData];
        self.receiveData.data = [NSData data];
        [self caculateDownloadFileSize];
        
        BOOL success = [self saveDownloadFile];
        if (success) {
            if ([self.delegate respondsToSelector:@selector(downloadDidFinish:filePath:)]) {
                [self.delegate downloadDidFinish:self filePath:self.downloadFilePath];
            }
        }
        else {
            if ([self.delegate respondsToSelector:@selector(downloadDidFail:errorType:)]) {
                [self.delegate downloadDidFail:self errorType:WGLM3U8DownloadErrorTypeCacheInDiskError];
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.downloadState = WGLDownloadStateFailed;
    [self caculateDownloadFileSize];

    if ([self.delegate respondsToSelector:@selector(downloadDidFail:errorType:)]) {
        [self.delegate downloadDidFail:self errorType:WGLM3U8DownloadErrorTypeHTTPError];
    }
}

#pragma mark - 保存下载文件

- (BOOL)saveDownloadFile {
    
    //将下载文件从temp移动到document
    NSString *fromPath = [self.tempDownloadFilePath copy];
    NSString *toPath = [self.downloadFilePath copy];
    NSError *error = nil;
    BOOL isMove = [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:&error];
    if (isMove && !error) {
        //保存成功
        return YES;
    }
    else {
        //保存失败
        return NO;
    }
}

#pragma mark - 下载目录/路径

//下载文件存放的目录
- (NSString *)downloadDirectory {
    if (!_downloadDirectory) {
        if ([self.dataSource respondsToSelector:@selector(downloaderGetDirectory:urlString:)]) {
            _downloadDirectory = [self.dataSource downloaderGetDirectory:self urlString:self.urlString];
        }
        if (_downloadDirectory.length < 5) {
            _downloadDirectory = self.defaultDirectory;
        }
    }
    return _downloadDirectory;
}

//下载文件存放的路径
- (NSString *)downloadFilePath {
    if (!_downloadFilePath) {
        _downloadFilePath = [self.downloadDirectory stringByAppendingPathComponent:self.cacheFileName];
        if (_downloadFilePath.length < 5) {
            _downloadFilePath = self.defaultFilePath;
        }
    }
    return _downloadFilePath;
}

#pragma mark - 默认下载目录/路径

//默认下载目录
- (NSString *)defaultDirectory {
    if (!_defaultDirectory) {
        _defaultDirectory = [[NSString alloc] initWithString:NSTemporaryDirectory()];
    }
    return _defaultDirectory;
}

//默认下载路径
- (NSString *)defaultFilePath {
    if (!_defaultFilePath) {
        _defaultFilePath = [self.defaultDirectory stringByAppendingPathComponent:self.cacheFileName];
    }
    return _defaultFilePath;
}

#pragma mark - 临时下载目录/路径

- (NSString *)tempDownloadDirectory {
    if (!_tempDownloadDirectory) {
        _tempDownloadDirectory = [NSString stringWithFormat:@"%@tempDownloadDirectory", self.defaultDirectory];
    }
    return _tempDownloadDirectory;
}

- (NSString *)tempDownloadFilePath {
    if (!_tempDownloadFilePath) {
        _tempDownloadFilePath = [self.tempDownloadDirectory stringByAppendingPathComponent:self.cacheFileName];
    }
    return _tempDownloadFilePath;
}

#pragma mark -

//文件缓存key
- (NSString *)cacheFileName {
    if (!_cacheFileName) {
        if ([self.dataSource respondsToSelector:@selector(downloaderCacheFileName:urlString:)]) {
            _cacheFileName = [self.dataSource downloaderCacheFileName:self urlString:self.urlString];
        }
        if (_cacheFileName.length < 5) {
            _cacheFileName = [self cachedFileNameForURLString:self.urlString];
        }
    }
    return _cacheFileName;
}

//url进行md5
- (NSString *)cachedFileNameForURLString:(NSString *)urlString {
    const char *str = urlString.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:urlString];
    NSString *ext = keyURL ? keyURL.pathExtension : urlString.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}

//获取磁盘总容量（单位B）
- (uint64_t)getDiskTotalSpace {
    uint64_t totalSpace = 0;
    __autoreleasing NSError *error = nil;
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:&error];
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
    }
    return totalSpace;
}

//获取磁盘剩余容量（单位B）
- (uint64_t)getDiskFreeSpace {
    uint64_t totalFreeSpace = 0;
    __autoreleasing NSError *error = nil;
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error: &error];
    if (dictionary) {
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
    }
    else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
    }
    return totalFreeSpace;
}

//获取某文件的大小
- (uint64_t)getFileSizeFromPath:(NSString *)filePath {
    if (!filePath) {
        return 0;
    }
    uint64_t fileSize = 0;
    const char *cPath = [filePath UTF8String];
    FILE *file = fopen(cPath, "r");
    if (file > 0) {
        fseek(file, 0, SEEK_END);
        fileSize = ftell(file);
        fseek(file, 0, SEEK_SET);
        fclose(file);
    }
    return fileSize;
}

//计算当前已下载文件的大小
- (void)caculateDownloadFileSize {
    uint64_t fileSize = [self getFileSizeFromPath:self.tempDownloadFilePath];
    self.downloadFileSize = fileSize;
}

@end


