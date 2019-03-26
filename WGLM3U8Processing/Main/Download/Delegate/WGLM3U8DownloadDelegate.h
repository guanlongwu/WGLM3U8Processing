//
//  WGLM3U8DownloadDelegate.h
//  WGLDownloadProvider
//
//  Created by wugl on 2019/3/26.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLM3U8Util.h"

@interface WGLM3U8DownloadDelegate : NSObject
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) WGLDownloadProviderStartBlock startBlock;
@property (nonatomic, copy) WGLDownloadProviderProgressBlock progressBlock;
@property (nonatomic, copy) WGLDownloadProviderSuccessBlock successBlock;
@property (nonatomic, copy) WGLDownloadProviderFailBlock failBlock;
@end
