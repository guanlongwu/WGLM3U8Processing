//
//  WGLM3U8Parser.m
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#define kMarkForTS  @"#EXTINF:"

#import "WGLM3U8Parser.h"

@interface WGLM3U8Parser ()
@property (nonatomic, copy) NSString *m3u8Content;
@property (nonatomic, strong) WGLM3U8Entity *m3u8Entity;
@property (nonatomic, copy) NSString *m3u8Url;
@end

@implementation WGLM3U8Parser

- (void)parseM3U8FilePath:(NSString *)filePath m3u8Url:(NSString *)urlString {
    [self parseM3U8FilePath:filePath m3u8Url:urlString completion:nil];
}

- (void)parseM3U8FilePath:(NSString *)filePath m3u8Url:(NSString *)urlString completion:(WGLM3U8ParseHandler)completion {
    //获取m3u8内容
    NSString *m3u8Content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    [self parseM3U8Content:m3u8Content m3u8Url:urlString completion:completion];
}

- (void)parseM3U8Content:(NSString *)m3u8Content m3u8Url:(NSString *)urlString {
    [self parseM3U8Content:m3u8Content m3u8Url:urlString completion:nil];
}

- (void)parseM3U8Content:(NSString *)m3u8Content m3u8Url:(NSString *)urlString completion:(WGLM3U8ParseHandler)completion {
    self.m3u8Content = m3u8Content;
    self.parseHandler = completion;
    
    if (m3u8Content.length == 0) {
        if (self.parseHandler) {
            self.parseHandler(self, NO);
        }
        return;
    }
    BOOL isValidM3U8 = [self checkIsValidM3U8:m3u8Content];
    if (NO == isValidM3U8) {
        if (self.parseHandler) {
            self.parseHandler(self, NO);
        }
        return;
    }
    self.m3u8Url = urlString;
    
    //解析m3u8内容，获取ts数据
    [self convertM3U8ToModel:m3u8Content];
}

#pragma mark -

- (void)convertM3U8ToModel:(NSString *)m3u8Content {
    NSString *m3u8String = [NSString stringWithFormat:@"%@", m3u8Content];
    NSMutableArray <WGLTSEntity *>* playList = [NSMutableArray array];
    
    NSRange segmentRange = [m3u8String rangeOfString:kMarkForTS];
    //逐个解析TS文件，并存储
    while (segmentRange.location != NSNotFound) {
        //声明一个entity存储TS文件链接和时长
        WGLTSEntity *ts = [[WGLTSEntity alloc] init];
        
        //读取TS片段时长
        NSRange commaRange = [m3u8String rangeOfString:@","];
        NSString *value = [m3u8String substringWithRange:NSMakeRange(segmentRange.location + [kMarkForTS length], commaRange.location - (segmentRange.location + [kMarkForTS length]))];
        ts.duration = [value integerValue];
        
        //截取M3U8
        m3u8String = [m3u8String substringFromIndex:commaRange.location];
        //获取TS下载链接
        NSRange linkRangeBegin = [m3u8String rangeOfString:@","];
        NSRange linkRangeEnd = [m3u8String rangeOfString:@".ts"];
        NSString *linkUrl = [m3u8String substringWithRange:NSMakeRange(linkRangeBegin.location + 2, (linkRangeEnd.location + 3) - (linkRangeBegin.location + 2))];
        ts.url = [self completeTSUrl:linkUrl];
        
        [playList addObject:ts];
        m3u8String = [m3u8String substringFromIndex:(linkRangeEnd.location + 3)];
        segmentRange = [m3u8String rangeOfString:kMarkForTS];
    }
    
    WGLM3U8Entity *m3u8Entity = [[WGLM3U8Entity alloc] init];
    m3u8Entity.playList = playList;
    self.m3u8Entity = m3u8Entity;
    
    if (self.parseHandler) {
        self.parseHandler(self, YES);
    }
}

#pragma mark - 检测合法性

- (BOOL)checkIsValidUrl:(NSString *)urlString {
    //判断是否是HTTP连接
    if (NO == ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"])) {
        return NO;
    }
    return YES;
}

- (BOOL)checkIsValidM3U8:(NSString *)m3u8Content {
    //解析TS文件
    NSRange segmentRange = [m3u8Content rangeOfString:@"#EXTINF:"];
    if (segmentRange.location == NSNotFound) {
        //M3U8里没有TS文件
        return NO;
    }
    return YES;
}

- (NSString *)completeTSUrl:(NSString *)urlString {
    if (NO == ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"])) {
        //ts文件下载url有可能不是完整的下载url，那么就是缺少了跟m3u8文件同一层目录的服务器路径
        if ([self checkIsValidUrl:self.m3u8Url]) {
            NSString *urlPrefix = [NSString stringWithFormat:@"%@", self.m3u8Url];
            while (NO == [urlPrefix hasSuffix:@"/"]) {
                urlPrefix = [urlPrefix substringToIndex:urlPrefix.length-1];
            }
            NSString *result = [NSString stringWithFormat:@"%@%@", urlPrefix, urlString];
            return result;
        }
    }
    return urlString;
}


@end
