//
//  HYLTS2MP4Processor.h
//  HYLTS2MP4Processor
//
//  Created by wugl on 2020/1/19.
//  Copyright © 2020 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class HYLTS2MP4Processor;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HYLConvertFailureReason) {
    HYLConvertFailureReasonError,  //转码失败
    HYLConvertFailureReasonIsRuning,  //当前有转码任务
};

typedef void(^HYLConvertSuccessBlock)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSString *mp4FilePath);   //转码成功回调
typedef void(^HYLConvertFailureBlock)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSError *error, HYLConvertFailureReason failureReason); //转码失败回调
typedef void(^HYLConvertProcessBlock)(HYLTS2MP4Processor *processor, NSString *tsFilePath, float process);    //转码进度回调
typedef void(^HYLConvertCancelBlock)(HYLTS2MP4Processor *processor, NSString *tsFilePath);  //取消转码回调

@interface HYLTS2MP4Delegate : NSObject

@property (nonatomic, copy) NSString *tsFilePath, *mp4FilePath;   //ts文件路径、mp4待转码文件路径
@property (nonatomic, copy) HYLConvertSuccessBlock successBlock;
@property (nonatomic, copy) HYLConvertFailureBlock failureBlock;
@property (nonatomic, copy) HYLConvertProcessBlock processBlock;
@property (nonatomic, copy) HYLConvertCancelBlock cancelBlock;

@end

@interface HYLTS2MP4Processor : NSObject

+ (HYLTS2MP4Processor *)sharedProcessor;

/**
 转码ts->mp4

 @param tsFilePath ts文件路径
 @param mp4FilePath mp4待转码输出的文件路径
 @param processBlock 进度回调
 @param successBlock 成功回调
 @param failureBlock 失败回调
 @param cancelBlock 取消转码回调
 */
- (void)convertWithTSFilePath:(NSString *)tsFilePath mp4FilePath:(NSString *)mp4FilePath processBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, float process))processBlock successBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSString *mp4FilePath))successBlock failureBlock:(void (^)(HYLTS2MP4Processor *processor, NSString *tsFilePath, NSError *error, HYLConvertFailureReason failureReason))failureBlock cancelBlock:(void(^)(HYLTS2MP4Processor *processor, NSString *tsFilePath))cancelBlock;

/**
 取消转码
 @param tsFilePath ts文件路径
 */
- (BOOL)cancelConvertWithTSFilePath:(NSString *)tsFilePath;

// ts文件路径
- (NSString *)tsFilePath;

// mp4待转码文件路径
- (NSString *)mp4FilePath;

// 当前有转码任务（可能还没开始转码，准备中或者转码中）
- (BOOL)isRuning;

// 转码中状态（真正的转码中状态）
- (BOOL)isConverting;

// 已转码完成的时间
- (int64_t)convertedTime;

// 待转码文件的总时长
- (int64_t)expectedConvertDuration;

@end

NS_ASSUME_NONNULL_END
