//
//  WGLDownloadProvider.m
//  WGLKit
//
//  Created by wugl on 2018/12/17.
//  Copyright © 2018年 WGLKit. All rights reserved.
//

#import "WGLDownloadProvider.h"
#import "WGLDownloadTask.h"
#import "WGLDownloader.h"
#import "WGLDownloadDelegate.h"
#import "WGLFileCache.h"

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

@interface WGLDownloadProvider () {
    dispatch_semaphore_t _lock;
}
@property (nonatomic, strong) NSMutableArray <WGLDownloadTask *> *tasks; //任务队列
@property (nonatomic, strong) NSMutableArray <WGLDownloader *> *downloaders; //下载队列
@property (nonatomic, strong) NSMutableDictionary <NSString *, WGLDownloadDelegate *> *taskDelegatesForUrl; //下载任务对应的回调代理
@end

@implementation WGLDownloadProvider

+ (instancetype)sharedProvider {
    static WGLDownloadProvider *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = dispatch_semaphore_create(1);
        _maxDownloadCount = -1;
        _executeOrder = WGLDownloadExeOrderFIFO;
        _tasks = [[NSMutableArray alloc] init];
        _downloaders = [[NSMutableArray alloc] init];
        _taskDelegatesForUrl = [[NSMutableDictionary alloc] init];
        [self setMaxConcurrentDownloadCount:2];
    }
    return self;
}

- (void)setMaxConcurrentDownloadCount:(NSInteger)maxConcurrentDownloadCount {
    if (_maxConcurrentDownloadCount != maxConcurrentDownloadCount) {
        _maxConcurrentDownloadCount = maxConcurrentDownloadCount;
        
        //创建下载器队列
        for (int i=0; i<maxConcurrentDownloadCount; i++) {
            WGLDownloader *downloader = [[WGLDownloader alloc] init];
            downloader.dataSource = (id<WGLDownloaderDataSource>)self;
            downloader.delegate = (id<WGLDownloaderDelegate>)self;
            [self.downloaders addObject:downloader];
        }
    }
}

+ (dispatch_queue_t)downloadQueue {
    static dispatch_queue_t dlQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlQueue = dispatch_queue_create("com.wugl.mobile.downloadProvider.downloadQueue", DISPATCH_QUEUE_SERIAL);
    });
    return dlQueue;
}

#pragma mark - main interface

//下载入口
- (void)downloadWithURL:(NSString *)urlString {
    [self downloadWithURL:urlString startBlock:nil progressBlock:nil successBlock:nil failBlock:nil];
}

- (void)downloadWithURL:(NSString *)urlString startBlock:(WGLDownloadProviderStartBlock)startBlock progressBlock:(WGLDownloadProviderProgressBlock)progressBlock successBlock:(WGLDownloadProviderSuccessBlock)successBlock failBlock:(WGLDownloadProviderFailBlock)failBlock {
    
    //设置delegate
    WGLDownloadDelegate *delegate = [[WGLDownloadDelegate alloc] init];
    delegate.urlString = urlString;
    delegate.startBlock = startBlock;
    delegate.progressBlock = progressBlock;
    delegate.successBlock = successBlock;
    delegate.failBlock = failBlock;
    [self setDelegate:delegate forUrlString:urlString];
    
    //是否命中缓存
    if ([self existInCache:urlString]) {
        return;
    }
    
    //已在任务队列中
    if ([self existInTasks:urlString]) {
        
        WGLDownloadTask *findTask = [self taskForUrl:urlString];
        if (findTask) {
            if (findTask.state == WGLDownloadStateWaiting
                && self.executeOrder == WGLDownloadExeOrderLIFO) {
                //调整下载优先级
                
                Lock();
                [self.tasks removeObject:findTask];
                [self.tasks insertObject:findTask atIndex:0];
                Unlock();
                
                return;
            }
            else {
                //作为新的下载任务，重新下载
                Lock();
                [self.tasks removeObject:findTask];
                Unlock();
            }
        }
    }
    
    //限制任务数
    [self limitTasksSize];
    
    //添加到任务队列
    WGLDownloadTask *task = [[WGLDownloadTask alloc] init];
    task.urlString = urlString;
    task.state = WGLDownloadStateWaiting;
    [self addTask:task];
    
    //触发下载
    [self startDownload];
}

- (void)addTask:(WGLDownloadTask *)task {
    if (!task) {
        return;
    }
    Lock();
    if (self.executeOrder == WGLDownloadExeOrderFIFO) {
        [self.tasks addObject:task];
    }
    else if (self.executeOrder == WGLDownloadExeOrderLIFO) {
        [self.tasks insertObject:task atIndex:0];
    }
    else {
        [self.tasks addObject:task];
    }
    Unlock();
}

//开始下载
- (void)startDownload {
    dispatch_async([WGLDownloadProvider downloadQueue], ^{
        for (WGLDownloader *downloader in self.downloaders) {
            //正在下载中
            if (downloader.downloadState == WGLDownloadStateDownloading) {
                continue;
            }
            
            //获取等待下载的任务
            WGLDownloadTask *task = [self preferredWaittingTask];
            if (task == nil) {
                //没有等待下载的任务
                break;
            }
            
            task.state = WGLDownloadStateDownloading;
            
            downloader.urlString = task.urlString;
            [downloader start];
        }
    });
}

//取消所有的下载
- (void)cancelAllDownloads {
    dispatch_async([WGLDownloadProvider downloadQueue], ^{
        [self.downloaders enumerateObjectsUsingBlock:^(WGLDownloader * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj cancel];
            
            //TODO:
            WGLDownloadTask *task = [self taskForUrl:obj.urlString];
            task.state = WGLDownloadStateCancelled;
        }];
    });
}

//取消指定下载
- (void)cancelDownloadURL:(NSString *)url {
    if (!url
        || url.length == 0) {
        return;
    }
    dispatch_async([WGLDownloadProvider downloadQueue], ^{
        [self.downloaders enumerateObjectsUsingBlock:^(WGLDownloader * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.urlString isEqualToString:url]) {
                [obj cancel];
                
                //TODO:
                WGLDownloadTask *task = [self taskForUrl:obj.urlString];
                task.state = WGLDownloadStateCancelled;
                *stop = YES;
            }
        }];
    });
}


#pragma mark - WGLDownloaderDelegate / datasource

- (NSString *)downloaderGetDirectory:(WGLDownloader *)downloader urlString:(NSString *)urlString {
    NSString *directory = nil;
    if ([self.dataSource respondsToSelector:@selector(downloadProvider:getDirectory:)]) {
        directory = [self.dataSource downloadProvider:self getDirectory:urlString];
    }
    return directory;
}

- (NSString *)downloaderCacheFileName:(WGLDownloader *)downloader urlString:(NSString *)urlString {
    NSString *fileName = nil;
    if ([self.dataSource respondsToSelector:@selector(downloadProvider:cacheFileName:)]) {
        fileName = [self.dataSource downloadProvider:self cacheFileName:urlString];
    }
    return fileName;
}

- (void)downloadDidStart:(WGLDownloader *)downloader {
    WGLDownloadTask *task = [self taskForUrl:downloader.urlString];
    if (!task) {
        return;
    }
    task.state = WGLDownloadStateDownloading;
    task.downloadFilePath = downloader.downloadFilePath;
    task.downloadFileSize = downloader.downloadFileSize;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(downloadDidStart:urlString:)]) {
            [self.delegate downloadDidStart:self urlString:downloader.urlString];
        }
        
        WGLDownloadDelegate *delegate = [self delegateForUrlString:downloader.urlString];
        if (delegate
            && [delegate.urlString isEqualToString:downloader.urlString]) {
            if (delegate.startBlock) {
                delegate.startBlock(self, downloader.urlString);
            }
        }
    });
}

- (void)downloader:(WGLDownloader *)downloader didReceiveLength:(uint64_t)receiveLength totalLength:(uint64_t)totalLength {
    WGLDownloadTask *task = [self taskForUrl:downloader.urlString];
    if (!task) {
        return;
    }
    task.state = WGLDownloadStateDownloading;
    task.receiveLength = receiveLength;
    task.totalLength = totalLength;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(downloader:urlString:didReceiveLength:totalLength:)]) {
            [self.delegate downloader:self urlString:downloader.urlString didReceiveLength:receiveLength totalLength:totalLength];
        }
        
        WGLDownloadDelegate *delegate = [self delegateForUrlString:downloader.urlString];
        if (delegate
            && [delegate.urlString isEqualToString:downloader.urlString]) {
            if (delegate.progressBlock) {
                delegate.progressBlock(self, downloader.urlString, receiveLength, totalLength);
            }
        }
    });
}

- (void)downloadDidFinish:(WGLDownloader *)downloader filePath:(NSString *)filePath {
    WGLDownloadTask *task = [self taskForUrl:downloader.urlString];
    if (!task) {
        return;
    }
    task.state = WGLDownloadStateFinish;
    task.receiveLength = task.totalLength;
    task.downloadFileSize = downloader.downloadFileSize;
    
    [self startDownload];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(downloadDidFinish:urlString:filePath:)]) {
            [self.delegate downloadDidFinish:self urlString:downloader.urlString filePath:filePath];
        }
        
        WGLDownloadDelegate *delegate = [self delegateForUrlString:downloader.urlString];
        if (delegate
            && [delegate.urlString isEqualToString:downloader.urlString]) {
            if (delegate.successBlock) {
                delegate.successBlock(self, downloader.urlString, filePath);
                
                [self removeDelegateForUrlString:downloader.urlString];
            }
        }
    });
}

- (void)downloadDidFail:(WGLDownloader *)downloader errorType:(WGLDownloadErrorType)errorType {
    WGLDownloadTask *task = [self taskForUrl:downloader.urlString];
    if (!task) {
        return;
    }
    task.state = WGLDownloadStateFailed;
    task.downloadFileSize = downloader.downloadFileSize;
    
    [self startDownload];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(downloadDidFail:urlString:errorType:)]) {
            [self.delegate downloadDidFail:self urlString:downloader.urlString errorType:errorType];
        }
        
        WGLDownloadDelegate *delegate = [self delegateForUrlString:downloader.urlString];
        if (delegate
            && [delegate.urlString isEqualToString:downloader.urlString]) {
            if (delegate.failBlock) {
                delegate.failBlock(self, downloader.urlString, errorType);
                
                [self removeDelegateForUrlString:downloader.urlString];
            }
        }
    });
}

#pragma mark - getter

- (WGLDownloadState)downloadStateForURL:(NSString *)url {
    __block WGLDownloadState state = WGLDownloadStateUnknow;
    Lock();
    [self.tasks enumerateObjectsUsingBlock:^(WGLDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.urlString isEqualToString:url]) {
            state = obj.state;
            *stop = YES;
        }
    }];
    Unlock();
    return state;
}


#pragma mark - private interface

//设置回调
- (void)setDelegate:(WGLDownloadDelegate *)delegate forUrlString:(NSString *)urlString {
    NSParameterAssert(urlString);
    NSParameterAssert(delegate);
    
    Lock();
    [self.taskDelegatesForUrl setObject:delegate forKey:urlString];
    Unlock();
}

//删除回调
- (void)removeDelegateForUrlString:(NSString *)urlString {
    NSParameterAssert(urlString);
    
    Lock();
    [self.taskDelegatesForUrl removeObjectForKey:urlString];
    Unlock();
}

//下载任务对应的回调
- (WGLDownloadDelegate *)delegateForUrlString:(NSString *)urlString {
    NSParameterAssert(urlString);
    
    WGLDownloadDelegate *delegate = nil;
    Lock();
    delegate = [self.taskDelegatesForUrl objectForKey:urlString];
    Unlock();
    return delegate;
}

//获取等待下载的任务
- (WGLDownloadTask *)preferredWaittingTask {
    WGLDownloadTask *findTask = nil;
    Lock();
    for (WGLDownloadTask *task in self.tasks) {
        if (task.state == WGLDownloadStateWaiting) {
            findTask = task;
        }
    }
    Unlock();
    return findTask;
}

//缓存是否命中
- (BOOL)existInCache:(NSString *)urlString {
    BOOL exist = NO;
    if ([self.dataSource respondsToSelector:@selector(downloadProvider:existCache:)]) {
        exist = [self.dataSource downloadProvider:self existCache:urlString];
    }
    return exist;
}

//已在任务队列
- (BOOL)existInTasks:(NSString *)urlString {
    __block BOOL exist = NO;
    Lock();
    [self.tasks enumerateObjectsUsingBlock:^(WGLDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.urlString isEqualToString:urlString]) {
            exist = YES;
            *stop = YES;
        }
    }];
    Unlock();
    return exist;
}

//获取url对应的任务
- (WGLDownloadTask *)taskForUrl:(NSString *)urlString {
    __block WGLDownloadTask *task = nil;
    Lock();
    [self.tasks enumerateObjectsUsingBlock:^(WGLDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.urlString isEqualToString:urlString]) {
            task = obj;
            *stop = YES;
        }
    }];
    Unlock();
    return task;
}

//限制任务数
- (void)limitTasksSize {
    if (self.maxDownloadCount == -1) {
        //不受限制
        return;
    }
    if (self.tasks.count <= self.maxDownloadCount) {
        return;
    }
    Lock();
    while (self.tasks.count > self.maxDownloadCount) {
        [self.tasks removeLastObject];
    }
    Unlock();
}

//移除下载任务
- (void)removeTask:(WGLDownloadTask *)task {
    if (!task) {
        return;
    }
    __block WGLDownloadTask *findTask = nil;
    Lock();
    [self.tasks enumerateObjectsUsingBlock:^(WGLDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.urlString isEqualToString:task.urlString]) {
            findTask = obj;
            *stop = YES;
        }
    }];
    if (findTask) {
        [self.tasks removeObject:findTask];
    }
    Unlock();
}

@end
