//
//  WGLM3U8Downloader.h
//  WGLM3U8DownloadProvider
//
//  Created by wugl on 2018/12/21.
//  Copyright © 2018年 WGLKit. All rights reserved.
//
/**
 SDK旧版本的弊端：
 文件下载的时候，如果边下载边缓存，但是下载中断了，导致缓存的文件不完整。
 如果通过SDK的缓存是否存在的接口判断，会认为缓存已存在，业务端可能就不再下载。
 导致与下载SDK的断点续传下载冲突了。
 
 修复方案：
 文件开始下载，下载中，存放的目录是一个临时目录self.tempDownloadDirectory
 在文件下载完成后，再将文件从临时目录迁移到指定的目录self.downloadDirectory
 所以，如果缓存的文件不完整（未下载完成），SDK判断缓存是否存在，是通过判断指定目录下是否有，
 因为只有文件下载完成了，指定目录下才会有缓存，所以这时候SDK就会进行断点续传下载。
 */

#import <Foundation/Foundation.h>
#import "WGLM3U8Util.h"
@class WGLM3U8DownloaderInfo;
@protocol WGLM3U8DownloaderDataSource;
@protocol WGLM3U8DownloaderDelegate;

@interface WGLM3U8Downloader : NSObject

@property (nonatomic, weak) id <WGLM3U8DownloaderDataSource> dataSource;
@property (nonatomic, weak) id <WGLM3U8DownloaderDelegate> delegate;

/**
 下载地址url
 */
@property (nonatomic, copy) NSString *urlString;

/**
 下载范围
 */
@property (nonatomic, assign) uint64_t fromByte, toByte;

/**
 下载文件存放路径
 */
@property (nonatomic, readonly) NSString *downloadFilePath;

/**
 下载文件大小
 */
@property (nonatomic, readonly) uint64_t downloadFileSize;

/**
 下载状态
 */
@property (nonatomic, readonly) WGLDownloadState downloadState;

/**
 开始下载
 */
- (void)start;

/**
 取消下载
 */
- (void)cancel;


@end


@protocol WGLM3U8DownloaderDataSource <NSObject>

//文件下载的存放目录
- (NSString *)downloaderGetDirectory:(WGLM3U8Downloader *)downloader urlString:(NSString *)urlString;

//文件缓存的唯一key
- (NSString *)downloaderCacheFileName:(WGLM3U8Downloader *)downloader urlString:(NSString *)urlString;

@end


@protocol WGLM3U8DownloaderDelegate <NSObject>

//下载开始
- (void)downloadDidStart:(WGLM3U8Downloader *)downloader;

//下载中
- (void)downloader:(WGLM3U8Downloader *)downloader didReceiveLength:(uint64_t)receiveLength totalLength:(uint64_t)totalLength;

//下载成功
- (void)downloadDidFinish:(WGLM3U8Downloader *)downloader filePath:(NSString *)filePath;

//下载失败
- (void)downloadDidFail:(WGLM3U8Downloader *)downloader errorType:(WGLM3U8DownloadErrorType)errorType;

@end



