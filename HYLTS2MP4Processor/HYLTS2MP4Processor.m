//
//  HYLTS2MP4Processor.m
//  HYLTS2MP4Processor
//
//  Created by wugl on 2020/1/19.
//  Copyright © 2020 WGLKit. All rights reserved.
//

#import "HYLTS2MP4Processor.h"
#import "FFmpegManager.h"

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

@implementation HYLTS2MP4Delegate

@end

@interface HYLTS2MP4Processor () {
    dispatch_semaphore_t _lock;
}
@property (nonatomic, copy) NSString *tsFilePath, *mp4FilePath;   //ts文件路径、mp4待转码文件路径
@property (nonatomic, assign) BOOL isRuning;    //当前有转码任务（可能还没开始转码，准备中或者转码中）
@property (nonatomic, assign) BOOL isConverting;    //转码中状态（真正的转码中状态）
@property (nonatomic, assign) int64_t convertedTime;    //已转码完成的时间
@property (nonatomic, assign) int64_t expectedConvertDuration; //待转码文件的总时长
@property (nonatomic, strong) NSMutableArray <HYLTS2MP4Delegate *> *delegates;
@end

@implementation HYLTS2MP4Processor

+ (HYLTS2MP4Processor *)sharedProcessor {
    static HYLTS2MP4Processor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = dispatch_semaphore_create(1);
        _delegates = [[NSMutableArray alloc] init];
        [self addNotifications];
    }
    return self;
}

#pragma mark - 转码

- (void)convertWithTSFilePath:(NSString *)tsFilePath mp4FilePath:(NSString *)mp4FilePath processBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, float process))processBlock successBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSString *mp4FilePath))successBlock failureBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSError *error, HYLConvertFailureReason failureReason))failureBlock cancelBlock:(void(^)(HYLTS2MP4Processor *processor, NSString *tsFilePath))cancelBlock {
    
    // 记录数据
    BOOL success = [self addDelegateIfNeededWithTSFilePath:tsFilePath mp4FilePath:mp4FilePath processBlock:processBlock successBlock:successBlock failureBlock:failureBlock cancelBlock:cancelBlock];
    if (success) {
        // 开始转码
        [self startConvertWithTSFilePath:tsFilePath mp4FilePath:mp4FilePath];
    }
}

- (void)startConvertWithTSFilePath:(NSString *)tsFilePath mp4FilePath:(NSString *)mp4FilePath {
    
    [[FFmpegManager sharedManager] convertWithTSFilePath:tsFilePath mp4FilePath:mp4FilePath processBlock:^(FFmpegManager *manager, NSString *tsFilePath, float process) {
        
        HYLTS2MP4Delegate *delegate = [self delegateForTSFilePath:tsFilePath];
        HYLConvertProcessBlock processBlock = delegate.processBlock;
        if (processBlock) {
            processBlock(self, tsFilePath, process);
        }
    } successBlock:^(FFmpegManager *manager, NSString *tsFilePath, NSString *mp4FilePath) {

        HYLTS2MP4Delegate *delegate = [self delegateForTSFilePath:tsFilePath];
        HYLConvertSuccessBlock successBlock = delegate.successBlock;
        if (successBlock) {
            successBlock(self, tsFilePath, mp4FilePath);
        }
        [self removeDelegateForTSFilePath:tsFilePath];
        [self continueConvertIfNeeded];
        
    } failureBlock:^(FFmpegManager *manager, NSString *tsFilePath, NSError *error, FMConvertFailureReason failureReason) {
        
        HYLTS2MP4Delegate *delegate = [self delegateForTSFilePath:tsFilePath];
        HYLConvertFailureBlock failureBlock = delegate.failureBlock;
        if (failureBlock) {
            failureBlock(self, tsFilePath, error, (HYLConvertFailureReason)failureReason);
        }
        [self removeDelegateForTSFilePath:tsFilePath];
        [self continueConvertIfNeeded];
        
    } cancelBlock:^(FFmpegManager *manager, NSString *tsFilePath) {
        
        HYLTS2MP4Delegate *delegate = [self delegateForTSFilePath:tsFilePath];
        HYLConvertCancelBlock cancelBlock = delegate.cancelBlock;
        if (cancelBlock) {
            cancelBlock(self, tsFilePath);
        }
        [self removeDelegateForTSFilePath:tsFilePath];
        
    }];
}

- (BOOL)cancelConvertWithTSFilePath:(NSString *)tsFilePath {
    if (tsFilePath.length == 0) {
        return NO;
    }
    [self removeDelegateForTSFilePath:tsFilePath];
    
    [[FFmpegManager sharedManager] cancelConvert];
    
    return YES;
}

#pragma mark - private

// 继续下一个转码
- (void)continueConvertIfNeeded {
    HYLTS2MP4Delegate *delegate = [self waitingDelegate];
    if (delegate) {
        NSString *tsFilePath = delegate.tsFilePath;
        NSString *mp4FilePath = delegate.mp4FilePath;
        
        [self startConvertWithTSFilePath:tsFilePath mp4FilePath:mp4FilePath];
    }
}

#pragma mark - 获取信息

- (NSString *)tsFilePath {
    return [FFmpegManager sharedManager].tsFilePath;
}

- (NSString *)mp4FilePath {
    return [FFmpegManager sharedManager].mp4FilePath;
}

// 当前有转码任务（可能还没开始转码，准备中或者转码中）
- (BOOL)isRuning {
    return [FFmpegManager sharedManager].isRuning;
}

// 转码中状态（真正的转码中状态）
- (BOOL)isConverting {
    return [FFmpegManager sharedManager].isConverting;
}

- (int64_t)convertedTime {
    return [FFmpegManager sharedManager].convertedTime;
}

- (int64_t)expectedConvertDuration {
    return [FFmpegManager sharedManager].expectedConvertDuration;
}

#pragma mark - delegate

- (BOOL)addDelegateIfNeededWithTSFilePath:(NSString *)tsFilePath mp4FilePath:(NSString *)mp4FilePath processBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, float process))processBlock successBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSString *mp4FilePath))successBlock failureBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSError *error, HYLConvertFailureReason failureReason))failureBlock cancelBlock:(void(^)(HYLTS2MP4Processor *processor, NSString *tsFilePath))cancelBlock {
    BOOL exist = [self isExistInQueueForTSFilePath:tsFilePath];
    if (NO == exist) {
        HYLTS2MP4Delegate *delegate = [[HYLTS2MP4Delegate alloc] init];
        delegate.tsFilePath = tsFilePath;
        delegate.mp4FilePath = mp4FilePath;
        delegate.successBlock = successBlock;
        delegate.failureBlock = failureBlock;
        delegate.processBlock = processBlock;
        delegate.cancelBlock = cancelBlock;
        Lock();
        [self.delegates addObject:delegate];
        Unlock();
        
        return YES;
    }
    return NO;
}

- (HYLTS2MP4Delegate *)delegateForTSFilePath:(NSString *)tsFilePath {
    if (tsFilePath.length == 0) {
        return nil;
    }
    __block HYLTS2MP4Delegate *delegate = nil;
    Lock();
    [self.delegates enumerateObjectsUsingBlock:^(HYLTS2MP4Delegate * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([tsFilePath isEqualToString:obj.tsFilePath]) {
            delegate = obj;
            *stop = YES;
        }
    }];
    Unlock();
    return delegate;
}

- (void)removeDelegateForTSFilePath:(NSString *)tsFilePath {
    if (tsFilePath.length == 0) {
        return;
    }
    HYLTS2MP4Delegate *delegate = [self delegateForTSFilePath:tsFilePath];
    if (delegate) {
        Lock();
        [self.delegates removeObject:delegate];
        Unlock();
    }
}

- (BOOL)isExistInQueueForTSFilePath:(NSString *)tsFilePath {
    if (tsFilePath.length == 0) {
        return NO;
    }
    __block BOOL exist = NO;
    Lock();
    [self.delegates enumerateObjectsUsingBlock:^(HYLTS2MP4Delegate * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([tsFilePath isEqualToString:obj.tsFilePath]) {
            exist = YES;
            *stop = YES;
        }
    }];
    Unlock();
    return exist;
}

- (HYLTS2MP4Delegate *)waitingDelegate {
    __block HYLTS2MP4Delegate *delegate = nil;
    Lock();
    if (self.delegates.count > 0) {
        delegate = [self.delegates firstObject];
    }
    Unlock();
    return delegate;
}

#pragma mark - 通知

- (void)addNotifications {
    // app退到后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    // app进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)appWillEnterBackground {
    [[FFmpegManager sharedManager] cancelConvert];
}

- (void)appDidBecomeActive {
    [self continueConvertIfNeeded];
}

@end
