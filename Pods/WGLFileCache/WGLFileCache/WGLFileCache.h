//
//  WGLFileCache.h
//  WGLFileCache
//
//  Created by wugl on 2019/2/21.
//  Copyright © 2019年 WGLKit. All rights reserved.
//
/**
 SDK弊端：
 文件下载的时候，如果边下载边缓存，但是下载中断了，导致缓存的文件不完整。
 如果通过SDK的缓存是否存在的接口判断，会认为缓存已存在，业务端可能就不再下载。
 导致与下载SDK的断点续传下载冲突了。
 */

#import <Foundation/Foundation.h>

@interface WGLFileCache : NSObject

//缓存单例
+ (instancetype)sharedCache;

/**
 缓存数据到内存和磁盘

 @param data NSData
 @param urlString url
 @return 缓存结果
 */
- (BOOL)storeCache:(NSData *)data forURLString:(NSString *)urlString;

/**
 缓存数据到磁盘

 @param data NSData
 @param urlString url
 @return 缓存结果
 */
- (BOOL)storeCacheToDisk:(NSData *)data forURLString:(NSString *)urlString;

/**
 获取缓存

 @param urlString url
 @param completion 缓存数据
 */
- (void)getCacheForURLString:(NSString *)urlString completion:(void(^)(NSData *cache))completion;

/**
 删除缓存从内存和磁盘

 @param urlString url
 @return 删除结果
 */
- (BOOL)removeCacheForURLString:(NSString *)urlString;

/**
 删除缓存从磁盘

 @param urlString url
 @return 删除结果
 */
- (BOOL)removeCacheFromDiskForURLString:(NSString *)urlString;

/**
 清空所有缓存从内存和磁盘
 */
- (void)clearAllCache;

/**
 清空所有缓存从磁盘
 */
- (void)clearAllCacheInDisk;

/**
 缓存是否存在于内存或者磁盘

 @param urlString url
 @return YES-缓存存在，NO-缓存不存在
 */
- (BOOL)cacheExistForURLString:(NSString *)urlString;

/**
 缓存是否存在于磁盘

 @param urlString url
 @return YES-缓存存在，NO-缓存不存在
 */
- (BOOL)cacheExistInDiskForURLString:(NSString *)urlString;

/**
 缓存的路径

 @param urlString url
 @param directory 缓存的目录
 @return 缓存的完整路径
 */
- (NSString *)cachePathForURLString:(NSString *)urlString inDirectory:(NSString *)directory;

/**
 缓存的默认路径

 @param urlString url
 @return 缓存的完整路径
 */
- (NSString *)defaultCachePathForURLString:(NSString *)urlString;

/**
 缓存的文件名

 @param urlString url
 @return 缓存的文件名
 */
- (NSString *)cacheFileNameForURLString:(NSString *)urlString;

/**
 缓存完整目录

 @param subPath 最后一层目录
 @return 缓存目录，如NSDocumentDirectory/xx/
 */
- (NSString *)getCacheDirectoryByAppendingPath:(NSString *)subPath;

/**
 缓存默认目录

 @return NSDocumentDirectory/defaultNameForWGLFileCache/
 */
- (NSString *)getDefaultCacheDirectory;


@end
