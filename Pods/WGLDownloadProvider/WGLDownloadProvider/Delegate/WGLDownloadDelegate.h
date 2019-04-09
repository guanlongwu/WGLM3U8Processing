//
//  WGLDownloadDelegate.h
//  WGLDownloadProvider
//
//  Created by wugl on 2019/3/26.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WGLDownloadUtil.h"

@interface WGLDownloadDelegate : NSObject
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) WGLDownloadProviderStartBlock startBlock;
@property (nonatomic, copy) WGLDownloadProviderProgressBlock progressBlock;
@property (nonatomic, copy) WGLDownloadProviderSuccessBlock successBlock;
@property (nonatomic, copy) WGLDownloadProviderFailBlock failBlock;
@end
