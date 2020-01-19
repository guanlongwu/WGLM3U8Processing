//
//  FFmpegManager.h
//  ZJHVideoProcessing
//
//  Created by ZhangJingHao2345 on 2018/1/29.
//  Copyright © 2018年 ZhangJingHao2345. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FFmpegManager;

typedef NS_ENUM(NSInteger, FMConvertFailureReason) {
    FMConvertFailureReasonError,  //转码失败
    FMConvertFailureReasonIsRuning,  //当前有转码任务
};

typedef void(^FMSuccessBlock)(FFmpegManager *manager, NSString *tsFilePath, NSString *mp4FilePath);   //转码成功回调
typedef void(^FMFailureBlock)(FFmpegManager *manager, NSString *tsFilePath, NSError *error, FMConvertFailureReason failureReason); //转码失败回调
typedef void(^FMProcessBlock)(FFmpegManager *manager, NSString *tsFilePath, float process);    //转码进度回调
typedef void(^FMCancelBlock)(FFmpegManager *manager, NSString *tsFilePath);    //取消转码回调

@interface FFmpegManager : NSObject
@property (nonatomic, copy) FMSuccessBlock successBlock;
@property (nonatomic, copy) FMFailureBlock failureBlock;
@property (nonatomic, copy) FMProcessBlock processBlock;
@property (nonatomic, copy) FMCancelBlock cancelBlock;

@property (nonatomic, copy, readonly) NSString *tsFilePath, *mp4FilePath;   //ts文件路径、mp4待转码文件路径
@property (nonatomic, assign, readonly) BOOL isRuning;    //当前有转码任务（可能还没开始转码，准备中或者转码中）
@property (nonatomic, assign, readonly) BOOL isConverting;    //转码中状态（真正的转码中状态）
@property (nonatomic, assign, readonly) int64_t convertedTime;    //已转码完成的时间
@property (nonatomic, assign, readonly) int64_t expectedConvertDuration; //待转码文件的总时长

+ (FFmpegManager *)sharedManager;

/**
 转码ts->mp4

 @param tsFilePath ts文件路径
 @param mp4FilePath mp4待转码输出的文件路径
 @param processBlock 进度回调
 @param successBlock 成功回调
 @param failureBlock 失败回调
 @param cancelBlock 取消转码回调
 */
- (void)convertWithTSFilePath:(NSString *)tsFilePath mp4FilePath:(NSString *)mp4FilePath processBlock:(void (^)(FFmpegManager *manager, NSString *tsFilePath, float process))processBlock successBlock:(void (^)(FFmpegManager *manager, NSString *tsFilePath, NSString *mp4FilePath))successBlock failureBlock:(void (^)(FFmpegManager *manager, NSString *tsFilePath, NSError *error, FMConvertFailureReason failureReason))failureBlock cancelBlock:(void(^)(FFmpegManager *manager, NSString *tsFilePath))cancelBlock;

// 取消转码
- (void)cancelConvert;

// 设置总时长
+ (void)setDuration:(long long)time;

// 设置当前时间
+ (void)setCurrentTime:(long long)time;

/**
 转换停止
 @param isCancel    是否取消转码导致停止
 */
+ (void)stopRuning:(BOOL)isCancel;

@end
