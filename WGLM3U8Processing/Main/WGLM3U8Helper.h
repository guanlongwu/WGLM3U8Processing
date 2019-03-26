//
//  WGLM3U8Helper.h
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/26.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WGLM3U8Helper : NSObject

+ (NSString *)cacheFilePath:(NSString *)urlString;

+ (NSString *)cacheDirectory;

+ (NSString *)cacheFileName:(NSString *)urlString;

+ (BOOL)existInCache:(NSString *)urlString;

+ (NSString *)cacheFileNameForURLString:(NSString *)urlString;


@end
