//
//  WGLM3U8Processing.m
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import "WGLM3U8Processing.h"
#import "WGLM3U8Parser.h"
#import "WGLM3U8DownloadManager.h"
#import "WGLFileCache.h"
#import "FFmpegManager.h"

@interface WGLM3U8Processing ()
@property (nonatomic, strong) WGLM3U8Parser *parser;
@property (nonatomic, strong) WGLM3U8DownloadManager *downloadManager;
@property (nonatomic, copy) NSString *m3u8Url;
@property (nonatomic, strong) NSMutableArray <NSString *> *filePaths;
@end

@implementation WGLM3U8Processing

+ (instancetype)sharedProcessing {
    static WGLM3U8Processing *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WGLM3U8Processing alloc] init];
    });
    return instance;
}

#pragma mark - 转码

- (void)m3u8ToMp4WithUrl:(NSString *)m3u8Url success:(WGLM3U8ProcessingSuccessBlock)success failure:(WGLM3U8ProcessingFailureBlock)failure {
    [self m3u8ToMp4WithUrl:m3u8Url downloadProgress:nil progress:nil success:success failure:failure];
}

- (void)m3u8ToMp4WithUrl:(NSString *)m3u8Url downloadProgress:(WGLM3U8DownloadProcessingProgressBlock)downloadProgressBlock progress:(WGLM3U8ProcessingProgressBlock)progress success:(WGLM3U8ProcessingSuccessBlock)success failure:(WGLM3U8ProcessingFailureBlock)failure {
    
    self.m3u8Url = m3u8Url;
    self.downloadProgressBlock = downloadProgressBlock;
    self.progressBlock = progress;
    self.successBlock = success;
    self.failureBlock = failure;
    
    __weak typeof(self) weakSelf = self;
    BOOL exist = [[WGLFileCache sharedCache] cacheExistForURLString:m3u8Url];
    if (exist) {
        //已下载好
        //下载好m3u8文件，进行解析
        NSString *filePath = [[WGLFileCache sharedCache] defaultCachePathForURLString:m3u8Url];
        [self.parser parseM3U8FilePath:filePath m3u8Url:m3u8Url completion:^(WGLM3U8Parser *parser, BOOL result) {
            if (result) {
                
                //3、解析好m3u8文件，开始循环下载ts文件
                weakSelf.filePaths = [NSMutableArray array];
                [weakSelf downloadTSFileWithIndex:0 playList:weakSelf.parser.m3u8Entity.playList];
            }
            else {
                NSLog(@"parse m3u8 file error!");
            }
        }];
        return;
    }
    
    //1、先下载m3u8文件，后解析，再拼接ts文件，最后再转码mp4
    [self.downloadManager downloadWithURL:m3u8Url  progress:^(NSString *urlString, uint64_t receiveLength, uint64_t totalLength) {
        
    } success:^(NSString *urlString, NSString *filePath) {
        
        //2、下载好m3u8文件，进行解析
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.parser parseM3U8FilePath:filePath m3u8Url:strongSelf.m3u8Url completion:^(WGLM3U8Parser *parser, BOOL result) {
            if (result) {
                
                //3、解析好m3u8文件，开始循环下载ts文件
                strongSelf.filePaths = [NSMutableArray array];
                [strongSelf downloadTSFileWithIndex:0 playList:strongSelf.parser.m3u8Entity.playList];
            }
            else {
                NSLog(@"parse m3u8 file error!");
            }
        }];
        
    } failure:^(NSString *urlString) {
        
    }];
}


#pragma mark - getter

- (WGLM3U8Parser *)parser {
    if (!_parser) {
        _parser = [[WGLM3U8Parser alloc] init];
    }
    return _parser;
}

- (WGLM3U8DownloadManager *)downloadManager {
    if (!_downloadManager) {
        _downloadManager = [[WGLM3U8DownloadManager alloc] init];
    }
    return _downloadManager;
}

#pragma mark - 转码准备

- (void)prepare {
    NSString *tsPath = [self compositeTsFilePath];
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:tsPath]) {
        BOOL success = [[NSFileManager defaultManager] createFileAtPath:tsPath contents:[NSData data] attributes:nil];
        if (NO == success) {
            NSLog(@"创建文件失败");
        }
    }
    else {
        NSError *error = nil;
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:tsPath error:&error];
        if (NO == success || error) {
            NSLog(@"remove file error!");
        }
        success = [[NSFileManager defaultManager] createFileAtPath:tsPath contents:[NSData data] attributes:nil];
        if (NO == success) {
            NSLog(@"创建文件失败");
        }
    }
}

#pragma mark - 下载TS文件、拼接TS文件、转码MP4

- (void)downloadTSFileWithIndex:(NSInteger)index playList:(NSMutableArray <WGLTSEntity *> *)playList {
    if (playList.count == 0) {
        return;
    }
    if (index >= playList.count) {
        //回调下载进度
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(self, self.m3u8Url, 1.0);
        }
        
        //4、下载完成，对所有ts文件进行拼接
        [self spliceTSFile];
        return;
    }
    
    WGLTSEntity *tsEntity = playList[index];
    NSString *url = tsEntity.url;
    
    //如果已经下载完成，则直接读缓存
    BOOL exist = [[WGLFileCache sharedCache] cacheExistForURLString:url];
    if (exist) {
        NSString *filePath = [[WGLFileCache sharedCache] defaultCachePathForURLString:url];
        if (filePath.length > 0) {
            [self.filePaths addObject:filePath];
        }
        
        //回调下载进度
        if (self.downloadProgressBlock) {
            float process = (float)(index + 1) / (float)playList.count;
            self.downloadProgressBlock(self, self.m3u8Url, process);
        }
        
        //依次下载下一段ts
        [self downloadTSFileWithIndex:index+1 playList:playList];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.downloadManager downloadWithURL:url progress:^(NSString *urlString, uint64_t receiveLength, uint64_t totalLength){
        if (weakSelf.downloadProgressBlock) {
            float process = (float)(index + 1) / (float)playList.count;
            weakSelf.downloadProgressBlock(weakSelf, weakSelf.m3u8Url, process);
        }
    } success:^(NSString *urlString, NSString *filePath) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (filePath) {
            [strongSelf.filePaths addObject:filePath];
        }
        
        //依次下载下一段ts
        [strongSelf downloadTSFileWithIndex:index+1 playList:playList];
        
    } failure:^(NSString *urlString) {
        NSLog(@"视频片段下载失败：index : %ld, urlString : %@", (long)index, urlString);
    }];
}

//拼接
- (void)spliceTSFile {
    //获取合成后视频的句柄
    NSString *tsPath = [self compositeTsFilePath];
    if (YES == [[NSFileManager defaultManager] fileExistsAtPath:tsPath]) {
        //文件已存在
        NSError *error = nil;
        BOOL result = [[NSFileManager defaultManager] removeItemAtPath:tsPath error:&error];
        if (NO == result
            || error) {
            NSLog(@"remove file fail!");
        }
    }
    
    //创建一个空的文件
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:tsPath contents:[NSData data] attributes:nil];
    if (NO == success) {
        NSLog(@"创建文件失败");
    }
    
    //开始合并
    NSFileHandle *fileHandler = [NSFileHandle fileHandleForWritingAtPath:tsPath];
    
    [self.filePaths enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        @autoreleasepool {
            NSData *data = [[NSData alloc] initWithContentsOfFile:obj];
            
            //合并的视频跟切片ts视频在同一层目录下
            [fileHandler writeData:data];
            
            //跳到文件末尾
            [fileHandler seekToEndOfFile];
        }
    }];
    
    //关闭文件
    [fileHandler closeFile];
    
    //5、合成视频后，进行转码 m3u8->mp4
    [self convert];
    
}

//转码
- (void)convert {
    NSString *inputPath = [self compositeTsFilePath];
    NSString *outputPath = [self mp4FilePath];
    if (YES == [[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        //mp4文件已存在
        
        if (self.successBlock) {
            self.successBlock(self, self.m3u8Url, inputPath, outputPath);
        }
        return;
    }
    [[FFmpegManager sharedManager] converWithInputPath:inputPath outputPath:outputPath processBlock:^(float process) {
        
        NSLog(@"转码进度：%.2f%%\n", process * 100);
        if (process > 0.99) {
            process = 0.99;
        }
        if (self.progressBlock) {
            self.progressBlock(self, self.m3u8Url, process);
        }

    } completionBlock:^(NSError *error) {
        
        if (error) {
            NSLog(@"转码失败 : %@", error);
            if (self.failureBlock) {
                self.failureBlock(self, self.m3u8Url);
            }
        } else {
            NSLog(@"转码成功，请在相应路径查看：%@\n", outputPath);
            if (self.successBlock) {
                self.successBlock(self, self.m3u8Url, inputPath, outputPath);
            }
        }
    }];
}

#pragma mark - 文件路径

- (NSString *)compositeTsFilePath {
    NSString *url = [self fileNameByTrimSuffix:self.m3u8Url];
    NSString *filePath = [self cacheFilePath:[NSString stringWithFormat:@"%@_input.ts", [[WGLFileCache sharedCache] cacheFileNameForURLString:url]]];
    return filePath;
}

- (NSString *)mp4FilePath {
    NSString *url = [self fileNameByTrimSuffix:self.m3u8Url];
    NSString *filePath = [self cacheFilePath:[NSString stringWithFormat:@"%@_output.mp4", [[WGLFileCache sharedCache] cacheFileNameForURLString:url]]];
    
    return filePath;
}

- (NSString *)cacheFilePath:(NSString *)urlString {
    NSString *filePath = [[WGLFileCache sharedCache] defaultCachePathForURLString:urlString];
    return filePath;
}

#pragma mark - private

//去掉文件名的后缀名 xxx.ts -> xxx
- (NSString *)fileNameByTrimSuffix:(NSString *)url {
    NSString *fileName = url;
    NSRange range = [url rangeOfString:@"." options:NSBackwardsSearch];
    if (range.length>0) {
        fileName = [url substringToIndex:NSMaxRange(range)];
    }
    fileName = [fileName substringToIndex:NSMaxRange(range) - 1];   //去掉.
    return fileName;
}



@end
