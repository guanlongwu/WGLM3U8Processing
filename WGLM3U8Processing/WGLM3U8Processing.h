//
//  WGLM3U8Processing.h
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//
/**
 核心指令：
 ffmpeg  -i  xx/xx/input.ts  -b:v  640k  xx/xx/output.mp4
 
 转码弊端：
 1、如果上述xx/xx/output.mp4已经存在，则ffmpeg上述指令会crash，
 因此，在执行上述指令之前，先确保output的路径文件不存在。
 2、如果在转码过程中，app发生crash退出了，会导致本地存在一份 非完整的mp4 缓存文件，
 下次进行转码的时候，会判断已经有缓存，而不会继续进行转码了。
 
 注意事项：
 如果合并后的ts文件重复合并了（合并后的ts文件大于真实视频大小），
 会导致ffmpeg读取视频时长duration和转码当前时间time出错（time/duration > 1，从而导致出现超过100%的转码进度）
 所以，合并ts视频文件，注意小心别出错。
 */

#import <Foundation/Foundation.h>
@class WGLM3U8Processing;

//下载进度回调block
typedef void(^WGLM3U8DownloadProcessingProgressBlock)(WGLM3U8Processing *processing, NSString *m3u8Url, float process);
//转码进度回调block
typedef void(^WGLM3U8ProcessingProgressBlock)(WGLM3U8Processing *processing, NSString *m3u8Url, float process);
//转码成功回调block
typedef void(^WGLM3U8ProcessingSuccessBlock)(WGLM3U8Processing *processing, NSString *m3u8Url, NSString *compositeTsFilePath, NSString *mp4FilePath);
//转码失败回调block
typedef void(^WGLM3U8ProcessingFailureBlock)(WGLM3U8Processing *processing, NSString *m3u8Url);

@interface WGLM3U8Processing : NSObject

@property (nonatomic, copy) WGLM3U8DownloadProcessingProgressBlock downloadProgressBlock;
@property (nonatomic, copy) WGLM3U8ProcessingSuccessBlock successBlock;
@property (nonatomic, copy) WGLM3U8ProcessingFailureBlock failureBlock;
@property (nonatomic, copy) WGLM3U8ProcessingProgressBlock progressBlock;

+ (instancetype)sharedProcessing;

- (void)m3u8ToMp4WithUrl:(NSString *)m3u8Url success:(WGLM3U8ProcessingSuccessBlock)success failure:(WGLM3U8ProcessingFailureBlock)failure;

- (void)m3u8ToMp4WithUrl:(NSString *)m3u8Url downloadProgress:(WGLM3U8DownloadProcessingProgressBlock)downloadProgressBlock progress:(WGLM3U8ProcessingProgressBlock)progress success:(WGLM3U8ProcessingSuccessBlock)success failure:(WGLM3U8ProcessingFailureBlock)failure;

@end
