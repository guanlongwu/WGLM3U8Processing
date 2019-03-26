//
//  WGLM3U8Util.h
//  WGLM3U8DownloadProvider
//
//  Created by wugl on 2019/2/19.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#ifndef WGLM3U8Util_h
#define WGLM3U8Util_h
@class WGLM3U8DownloadProvider;

typedef NS_ENUM(NSInteger, WGLM3U8DownloadErrorType) {
    WGLM3U8DownloadErrorTypeHTTPError,              //http网络错误
    WGLM3U8DownloadErrorTypeInvalidURL,             //非法URL
    WGLM3U8DownloadErrorTypeInvalidDirectory,       //非法下载目录
    WGLM3U8DownloadErrorTypeInvalidRequestRange,    //非法下载请求范围
    WGLM3U8DownloadErrorTypeNotEnoughFreeSpace,     //下载空间不足
    WGLM3U8DownloadErrorTypeCacheInDiskError,       //磁盘缓存失败
};

typedef NS_ENUM(NSInteger, WGLDownloadState) {
    WGLDownloadStateUnknow,             //未知
    WGLDownloadStateWaiting = 1,        //等待下载中
    WGLDownloadStateDownloading,        //正在下载中
    WGLDownloadStateFinish,             //下载完成
    WGLDownloadStateCancelled,          //下载取消
    WGLDownloadStateFailed,             //下载失败
};

//下载开始回调
typedef void(^WGLDownloadProviderStartBlock)(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString);

//下载中回调
typedef void(^WGLDownloadProviderProgressBlock)(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString, uint64_t receiveLength, uint64_t totalLength);

//下载成功回调
typedef void(^WGLDownloadProviderSuccessBlock)(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString, NSString *filePath);

//下载失败回调
typedef void(^WGLDownloadProviderFailBlock)(WGLM3U8DownloadProvider *dlProvider, NSString *_urlString, WGLM3U8DownloadErrorType errorType);



#endif /* WGLM3U8Util_h */
