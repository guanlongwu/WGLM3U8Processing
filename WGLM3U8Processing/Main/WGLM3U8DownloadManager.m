//
//  WGLM3U8DownloadManager.m
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import "WGLM3U8DownloadManager.h"
#import "WGLM3U8DownloadProvider.h"
#import "WGLM3U8Helper.h"

@interface WGLM3U8DownloadManager ()
@property (nonatomic, strong) WGLM3U8DownloadProvider *downloadProvider;
@end

@implementation WGLM3U8DownloadManager

#pragma mark - 下载

- (void)downloadWithURL:(NSString *)urlString success:(void(^)(NSString *urlString, NSString *filePath))success failure:(void(^)(NSString *urlString))failure {
    self.urlString = urlString;
    self.downloadProvider.maxConcurrentDownloadCount = 1;   //排队下载
    [self.downloadProvider downloadWithURL:urlString startBlock:^(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString) {
        
    } progressBlock:^(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString, uint64_t receiveLength, uint64_t totalLength) {
        
    } successBlock:^(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString, NSString *filePath) {
        if (success) {
            success(_urlString, filePath);
        }
    } failBlock:^(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString, WGLM3U8DownloadErrorType errorType) {
        if (failure) {
            failure(_urlString);
        }
        
        NSString *errorMsg = @"";
        switch (errorType) {
            case WGLM3U8DownloadErrorTypeHTTPError:
                errorMsg = @"HTTP请求出错";
                break;
            case WGLM3U8DownloadErrorTypeInvalidURL:
                errorMsg = @"URL不合法";
                break;
            case WGLM3U8DownloadErrorTypeInvalidRequestRange:
                errorMsg = @"下载范围不对";
                break;
            case WGLM3U8DownloadErrorTypeInvalidDirectory:
                errorMsg = @"下载目录出错";
                break;
            case WGLM3U8DownloadErrorTypeNotEnoughFreeSpace:
                errorMsg = @"磁盘空间不足";
                break;
            case WGLM3U8DownloadErrorTypeCacheInDiskError:
                errorMsg = @"下载成功缓存失败";
                break;
            default:
                break;
        }
        NSLog(@"error msg : %@", errorMsg);
    }];
}

- (WGLM3U8DownloadProvider *)downloadProvider {
    if (!_downloadProvider) {
        _downloadProvider = [[WGLM3U8DownloadProvider alloc] init];
        _downloadProvider.delegate = (id<WGLM3U8DownloadProviderDelegate>)self;
        _downloadProvider.dataSource = (id<WGLM3U8DownloadProviderDataSource>)self;
    }
    return _downloadProvider;
}

#pragma mark - WGLM3U8DownloadProviderDataSource / delegate

//是否已缓存
- (BOOL)downloadProvider:(WGLM3U8DownloadProvider *)dlProvider existCache:(NSString *)urlString {
    BOOL exist = [WGLM3U8Helper existInCache:urlString];
    return exist;
}

//文件下载的存放目录
- (NSString *)downloadProvider:(WGLM3U8DownloadProvider *)dlProvider getDirectory:(NSString *)urlString {
    NSString *dir = [WGLM3U8Helper cacheDirectory];
    return dir;
}

//文件缓存的唯一key
- (NSString *)downloadProvider:(WGLM3U8DownloadProvider *)dlProvider cacheFileName:(NSString *)urlString {
    NSString *cacheName = [WGLM3U8Helper cacheFileName:urlString];
    return cacheName;
}

@end
