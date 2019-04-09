//
//  WGLM3U8DownloadManager.h
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
@class WGLM3U8DownloadManager;

typedef void(^WGLM3U8DownloadManagerHandler)(WGLM3U8DownloadManager *manager, NSString *urlString, NSString *filePath);

@interface WGLM3U8DownloadManager : NSObject

@property (nonatomic, copy) NSString *urlString;

//下载
- (void)downloadWithURL:(NSString *)urlString progress:(void(^)(NSString *urlString, uint64_t receiveLength, uint64_t totalLength))progress success:(void(^)(NSString *urlString, NSString *filePath))success failure:(void(^)(NSString *urlString))failure;

@end
