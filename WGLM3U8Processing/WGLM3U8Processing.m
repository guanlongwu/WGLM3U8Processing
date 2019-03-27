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
#import "WGLM3U8Helper.h"
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

- (void)m3u8ToMp4:(NSString *)m3u8Url success:(WGLM3U8ProcessingSuccessBlock)success failure:(WGLM3U8ProcessingFailureBlock)failure {
    [self m3u8ToMp4:m3u8Url progress:nil success:success failure:failure];
}

- (void)m3u8ToMp4:(NSString *)m3u8Url progress:(WGLM3U8ProcessingProgressBlock)progress success:(WGLM3U8ProcessingSuccessBlock)success failure:(WGLM3U8ProcessingFailureBlock)failure {
    self.m3u8Url = m3u8Url;
    self.progressBlock = progress;
    self.successBlock = success;
    self.failureBlock = failure;
    
    //1、先下载m3u8文件，后解析，再拼接ts文件，最后再转码mp4
    __weak typeof(self) weakSelf = self;
    [self.downloadManager downloadWithURL:m3u8Url success:^(NSString *urlString, NSString *filePath) {
        
        //2、下载好m3u8文件，进行解析
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.parser parseM3U8FilePath:filePath m3u8Url:strongSelf.m3u8Url];
        
    } failure:^(NSString *urlString) {
        
    }];
}


#pragma mark - getter

- (WGLM3U8Parser *)parser {
    if (!_parser) {
        _parser = [[WGLM3U8Parser alloc] init];
        __weak typeof(self) weakSelf = self;
        _parser.parseHandler = ^(WGLM3U8Parser *parser, BOOL result) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (result) {
                
                //3、解析好m3u8文件，开始循环下载ts文件
                strongSelf.filePaths = [NSMutableArray array];
                [strongSelf downloadTSFileWithIndex:0 playList:strongSelf.parser.m3u8Entity.playList];
            }
            else {
                
            }
        };
    }
    return _parser;
}

- (WGLM3U8DownloadManager *)downloadManager {
    if (!_downloadManager) {
        _downloadManager = [[WGLM3U8DownloadManager alloc] init];
    }
    return _downloadManager;
}

#pragma mark - 下载TS文件、拼接TS文件、转码MP4

- (void)downloadTSFileWithIndex:(NSInteger)index playList:(NSMutableArray <WGLTSEntity *> *)playList {
    if (index >= playList.count) {
        
        //4、下载完成，对所有ts文件进行拼接
        [self spliceTSFile];
        return;
    }
    
    WGLTSEntity *tsEntity = playList[index];
    NSString *url = tsEntity.url;
    
    __weak typeof(self) weakSelf = self;
    [self.downloadManager downloadWithURL:url success:^(NSString *urlString, NSString *filePath) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (filePath) {
            [strongSelf.filePaths addObject:filePath];
        }
        
        //依次下载下一段ts
        [strongSelf downloadTSFileWithIndex:index+1 playList:playList];
        
    } failure:^(NSString *urlString) {
        
    }];
}

//拼接
- (void)spliceTSFile {
    [self.filePaths enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSData *data = [[NSData alloc] initWithContentsOfFile:obj];
        
        //合并的视频跟切片ts视频在同一层目录下
        NSString *tsPath = [self compositeTsFilePath];
        NSFileHandle *fileHandler = [NSFileHandle fileHandleForWritingAtPath:tsPath];
        [fileHandler writeData:data];
    }];
    
    //5、合成视频后，进行转码 m3u8->mp4
    [self convert];
    
}

//转码
- (void)convert {
    NSString *inputPath = [self compositeTsFilePath];
    NSString *outputPath = [self mp4FilePath];
    [[FFmpegManager sharedManager] converWithInputPath:inputPath outputPath:outputPath processBlock:^(float process) {
        
        NSLog(@"转码进度：%.2f%%\n", process * 100);
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
            NSLog(@"转码成功，请在相应路径查看：%@\n", [self mp4FilePath]);
            if (self.successBlock) {
                self.successBlock(self, self.m3u8Url, [self mp4FilePath]);
            }
        }
    }];
}

#pragma mark - private

- (NSString *)compositeTsFilePath {
    return [WGLM3U8Helper cacheFilePath:@"合成的原视频.ts"];
}

- (NSString *)mp4FilePath {
    return [WGLM3U8Helper cacheFilePath:@"转码后的视频.mp4"];
}



@end
