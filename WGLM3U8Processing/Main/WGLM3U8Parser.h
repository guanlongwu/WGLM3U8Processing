//
//  WGLM3U8Parser.h
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//
/**
 m3u8解析：
 拿到一个M3U8链接后，解析出M3U8索引的具体内容，包括每一个TS的下载链接、时长等，封装到Model中，供后面使用；
 */

#import <Foundation/Foundation.h>
#import "WGLM3U8Entity.h"
@class WGLM3U8Parser;

typedef void(^WGLM3U8ParseHandler)(WGLM3U8Parser *parser, BOOL result);    //解析回调

@interface WGLM3U8Parser : NSObject

@property (nonatomic, copy, readonly) NSString *m3u8Content;
@property (nonatomic, strong, readonly) WGLM3U8Entity *m3u8Entity;
@property (nonatomic, copy) WGLM3U8ParseHandler parseHandler;

/**
 解析M3U8文件

 @param filePath M3U8文件的本地路径
 @param urlString M3U8文件的下载地址
 */
- (void)parseM3U8FilePath:(NSString *)filePath m3u8Url:(NSString *)urlString;

@end
