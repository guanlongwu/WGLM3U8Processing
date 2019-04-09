//
//  WGLFileCache.m
//  WGLFileCache
//
//  Created by wugl on 2019/2/21.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import "WGLFileCache.h"
#import <CommonCrypto/CommonDigest.h>

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

static const NSString *kCacheDefaultName = @"defaultNameForWGLFileCache";

@interface WGLFileCache () {
    dispatch_semaphore_t _lock;
}
@property (nonatomic, strong) dispatch_queue_t ioQueue;//io操作队列
@property (nonatomic, strong) NSCache *memCache;
@end

@implementation WGLFileCache

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)sharedCache {
    static WGLFileCache *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = dispatch_semaphore_create(1);
        _memCache = [[NSCache alloc] init];
        _ioQueue = dispatch_queue_create("com.wugl.WGLFileCache.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)storeCache:(NSData *)data forURLString:(NSString *)urlString {
    if (!data || urlString.length == 0) {
        return NO;
    }
    Lock();
    [self.memCache setObject:data forKey:urlString];
    Unlock();
    BOOL result = NO;
    @autoreleasepool {
        result = [self storeCacheToDisk:data forURLString:urlString];
    }
    return result;
}

- (BOOL)storeCacheToDisk:(NSData *)data forURLString:(NSString *)urlString {
    if (!data || urlString.length == 0) {
        return NO;
    }
    dispatch_async(self.ioQueue, ^{
        if (![[NSFileManager defaultManager] fileExistsAtPath:[self getDefaultCacheDirectory]]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[self getDefaultCacheDirectory] withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        NSString *cachePathForKey = [self defaultCachePathForURLString:urlString];
        [[NSFileManager defaultManager] createFileAtPath:cachePathForKey contents:data attributes:nil];
    });
    return YES;
}

- (void)getCacheForURLString:(NSString *)urlString completion:(void(^)(NSData *cache))completion {
    if (urlString.length == 0) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    dispatch_async(self.ioQueue, ^{
        //首先取缓存
        Lock();
        NSData *diskData = [self.memCache objectForKey:urlString];
        Unlock();
        if (!diskData) {
            //缓存没有，取磁盘
            @autoreleasepool {
                diskData = [self diskFileDataBySearchingAllPathsForKey:urlString];
            }
        }
        if (completion) {
            completion(diskData);
        }
    });
}

- (BOOL)removeCacheForURLString:(NSString *)urlString {
    if (urlString.length == 0) {
        return NO;
    }
    Lock();
    [self.memCache removeObjectForKey:urlString];
    Unlock();
    BOOL result = [self removeCacheFromDiskForURLString:urlString];
    return result;
}

- (BOOL)removeCacheFromDiskForURLString:(NSString *)urlString {
    if (urlString.length == 0) {
        return NO;
    }
    dispatch_async(self.ioQueue, ^{
        NSError *error = nil;
        BOOL result = [[NSFileManager defaultManager] removeItemAtPath:[self defaultCachePathForURLString:urlString] error:&error];
        BOOL success = (result && error == nil);
        if (NO == success) {
            
        }
    });
    return YES;
}

- (void)clearAllCache {
    Lock();
    [self.memCache removeAllObjects];
    Unlock();
    [self clearAllCacheInDisk];
}

- (void)clearAllCacheInDisk {
    dispatch_async(self.ioQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:[self getDefaultCacheDirectory] error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:[self getDefaultCacheDirectory]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
}

- (BOOL)cacheExistForURLString:(NSString *)urlString {
    if (urlString.length == 0) {
        return NO;
    }
    Lock();
    NSData *data = [self.memCache objectForKey:urlString];
    Unlock();
    if (!data) {
        return [self cacheExistInDiskForURLString:urlString];
    }
    return YES;
}

- (BOOL)cacheExistInDiskForURLString:(NSString *)urlString {
    if (urlString.length == 0) {
        return NO;
    }
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForURLString:urlString]];
    if (!exists) {
        exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForURLString:urlString].stringByDeletingPathExtension];
    }
    if (exists) {
        //磁盘有，则缓存一份到内存
        dispatch_async(self.ioQueue, ^{
            [self getCacheForURLString:urlString completion:^(NSData *cache) {
                if (cache) {
                    Lock();
                    [self.memCache setObject:cache forKey:urlString];
                    Unlock();
                }
            }];
        });
    }
    return exists;
}

#pragma mark - Cache paths

- (NSString *)cachePathForURLString:(NSString *)urlString inDirectory:(NSString *)directory {
    if (![[NSFileManager defaultManager] fileExistsAtPath:directory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSString *filename = [self cacheFileNameForURLString:urlString];
    return [directory stringByAppendingPathComponent:filename];
}

- (NSString *)defaultCachePathForURLString:(NSString *)urlString {
    return [self cachePathForURLString:urlString inDirectory:[self getDefaultCacheDirectory]];
}

- (NSString *)cacheFileNameForURLString:(NSString *)urlString {
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

- (NSString *)getCacheDirectoryByAppendingPath:(NSString *)subPath {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths[0] stringByAppendingPathComponent:subPath];
    return dir;
}

- (NSString *)getDefaultCacheDirectory {
    NSString *dir = [self getCacheDirectoryByAppendingPath:[NSString stringWithFormat:@"%@", kCacheDefaultName]];
//    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
//        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
//    }
    return dir;
}

#pragma mark - private

- (void)checkIfQueueIsIOQueue {
    const char *currentQueueLabel = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    const char *ioQueueLabel = dispatch_queue_get_label(self.ioQueue);
    if (strcmp(currentQueueLabel, ioQueueLabel) != 0) {
        NSLog(@"This method should be called from the ioQueue");
    }
}

//获取Key对应的文件缓存
- (nullable NSData *)diskFileDataBySearchingAllPathsForKey:(nullable NSString *)key {
    NSString *defaultPath = [self defaultCachePathForURLString:key];
    NSData *data = [self diskFileDataBySearchingAllPathsForPath:defaultPath];
    return data;
}

//获取路径下的文件缓存
- (nullable NSData *)diskFileDataBySearchingAllPathsForPath:(nullable NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:nil];
    if (data) {
        return data;
    }
    data = [NSData dataWithContentsOfFile:path.stringByDeletingPathExtension options:NSDataReadingUncached error:nil];
    if (data) {
        return data;
    }
    return nil;
}

#pragma mark - Cache Info

//获取磁盘缓存使用的大小。
- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[self getDefaultCacheDirectory]];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [[self getDefaultCacheDirectory] stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

//获取磁盘缓存中的文件数量。
- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[self getDefaultCacheDirectory]];
        count = fileEnumerator.allObjects.count;
    });
    return count;
}

//异步计算磁盘缓存的大小。
- (void)calculateSizeWithCompletionBlock:(void(^)(NSUInteger fileCount, NSUInteger totalSize))completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:[self getDefaultCacheDirectory] isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:diskCacheURL
                                                       includingPropertiesForKeys:@[NSFileSize]
                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                     errorHandler:NULL];
        
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!url) {
        return @"";
    }
    return url.absoluteString;
}

@end
