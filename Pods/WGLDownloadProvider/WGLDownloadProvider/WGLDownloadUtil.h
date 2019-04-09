//
//  WGLDownloadUtil.h
//  WGLDownloadProvider
//
//  Created by wugl on 2019/2/19.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#ifndef WGLDownloadUtil_h
#define WGLDownloadUtil_h
@class WGLDownloadProvider;

typedef NS_ENUM(NSInteger, WGLDownloadErrorType) {
    WGLDownloadErrorTypeHTTPError,              //http网络错误
    WGLDownloadErrorTypeInvalidURL,             //非法URL
    WGLDownloadErrorTypeInvalidDirectory,       //非法下载目录
    WGLDownloadErrorTypeInvalidRequestRange,    //非法下载请求范围
    WGLDownloadErrorTypeNotEnoughFreeSpace,     //下载空间不足
    WGLDownloadErrorTypeCacheInDiskError,       //磁盘缓存失败
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
typedef void(^WGLDownloadProviderStartBlock)(WGLDownloadProvider *dlProvider, NSString *_urlString);

//下载中回调
typedef void(^WGLDownloadProviderProgressBlock)(WGLDownloadProvider *dlProvider, NSString *_urlString, uint64_t receiveLength, uint64_t totalLength);

//下载成功回调
typedef void(^WGLDownloadProviderSuccessBlock)(WGLDownloadProvider *dlProvider, NSString *_urlString, NSString *filePath);

//下载失败回调
typedef void(^WGLDownloadProviderFailBlock)(WGLDownloadProvider *dlProvider, NSString *_urlString, WGLDownloadErrorType errorType);


#endif /* WGLDownloadUtil_h */
