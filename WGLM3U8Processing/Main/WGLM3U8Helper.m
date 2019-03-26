//
//  WGLM3U8Helper.m
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/26.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import "WGLM3U8Helper.h"
#import <CommonCrypto/CommonDigest.h>

@implementation WGLM3U8Helper

+ (NSString *)cacheFilePath:(NSString *)urlString {
    NSString *filePath = [[self cacheDirectory] stringByAppendingPathComponent:[self cacheFileName:urlString]];
    return filePath;
}

+ (NSString *)cacheDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths[0] stringByAppendingPathComponent:@"m3u8FileCache"];
    return dir;
}

+ (NSString *)cacheFileName:(NSString *)urlString {
    NSString *cacheName = [self cacheFileNameForURLString:urlString];
    return cacheName;
}

+ (BOOL)existInCache:(NSString *)urlString {
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[self cacheFilePath:urlString]];
    if (!exists) {
        exists = [[NSFileManager defaultManager] fileExistsAtPath:[self cacheFilePath:urlString].stringByDeletingPathExtension];
    }
    return exists;
}

+ (NSString *)cacheFileNameForURLString:(NSString *)urlString {
    const char *str = urlString.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:urlString];
    NSString *ext = keyURL ? keyURL.pathExtension : urlString.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}

@end
