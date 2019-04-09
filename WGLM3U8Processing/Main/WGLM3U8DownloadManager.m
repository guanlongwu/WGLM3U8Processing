//
//  WGLM3U8DownloadManager.m
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import "WGLM3U8DownloadManager.h"
#import "WGLDownloadProvider.h"
#import "WGLFileCache.h"

@interface WGLM3U8DownloadManager ()
@property (nonatomic, strong) WGLDownloadProvider *downloadProvider;
@end

@implementation WGLM3U8DownloadManager

#pragma mark - 下载

- (void)downloadWithURL:(NSString *)urlString progress:(void(^)(NSString *urlString, uint64_t receiveLength, uint64_t totalLength))progress success:(void(^)(NSString *urlString, NSString *filePath))success failure:(void(^)(NSString *urlString))failure {
    self.urlString = urlString;
    self.downloadProvider.maxConcurrentDownloadCount = 1;   //排队下载
    [self.downloadProvider downloadWithURL:urlString startBlock:^(WGLDownloadProvider *dlProvider, NSString *_urlString) {
        
    } progressBlock:^(WGLDownloadProvider *dlProvider, NSString *_urlString, uint64_t receiveLength, uint64_t totalLength) {
        if (progress) {
            progress(_urlString, receiveLength, totalLength);
        }
    } successBlock:^(WGLDownloadProvider *dlProvider, NSString *_urlString, NSString *filePath) {
        if (success) {
            success(_urlString, filePath);
        }
    } failBlock:^(WGLDownloadProvider *dlProvider, NSString *_urlString, WGLDownloadErrorType errorType) {
        if (failure) {
            failure(_urlString);
        }
        
        NSString *errorMsg = @"";
        switch (errorType) {
            case WGLDownloadErrorTypeHTTPError:
                errorMsg = @"HTTP请求出错";
                break;
            case WGLDownloadErrorTypeInvalidURL:
                errorMsg = @"URL不合法";
                break;
            case WGLDownloadErrorTypeInvalidRequestRange:
                errorMsg = @"下载范围不对";
                break;
            case WGLDownloadErrorTypeInvalidDirectory:
                errorMsg = @"下载目录出错";
                break;
            case WGLDownloadErrorTypeNotEnoughFreeSpace:
                errorMsg = @"磁盘空间不足";
                break;
            case WGLDownloadErrorTypeCacheInDiskError:
                errorMsg = @"下载成功缓存失败";
                break;
            default:
                break;
        }
        NSLog(@"error msg : %@", errorMsg);
    }];
}

- (WGLDownloadProvider *)downloadProvider {
    if (!_downloadProvider) {
        _downloadProvider = [[WGLDownloadProvider alloc] init];
        _downloadProvider.delegate = (id<WGLDownloadProviderDelegate>)self;
        _downloadProvider.dataSource = (id<WGLDownloadProviderDataSource>)self;
    }
    return _downloadProvider;
}

#pragma mark - WGLDownloadProvider datasource / delegate

//是否已缓存
- (BOOL)downloadProvider:(WGLDownloadProvider *)dlProvider existCache:(NSString *)urlString {
    BOOL exist = [[WGLFileCache sharedCache] cacheExistForURLString:urlString];
    return exist;
}

//文件下载的存放目录
- (NSString *)downloadProvider:(WGLDownloadProvider *)dlProvider getDirectory:(NSString *)urlString {
    NSString *dir = [[WGLFileCache sharedCache] getDefaultCacheDirectory];
    return dir;
}

//文件缓存的唯一key
- (NSString *)downloadProvider:(WGLDownloadProvider *)dlProvider cacheFileName:(NSString *)urlString {
    NSString *cacheName = [[WGLFileCache sharedCache] cacheFileNameForURLString:urlString];
    return cacheName;
}

@end
