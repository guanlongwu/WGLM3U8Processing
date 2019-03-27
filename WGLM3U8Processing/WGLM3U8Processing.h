//
//  WGLM3U8Processing.h
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>
@class WGLM3U8Processing;

typedef void(^WGLM3U8ProcessingSuccessBlock)(WGLM3U8Processing *processing, NSString *m3u8Url, NSString *mp4FilePath);

typedef void(^WGLM3U8ProcessingFailureBlock)(WGLM3U8Processing *processing, NSString *m3u8Url);

@interface WGLM3U8Processing : NSObject

@property (nonatomic, copy) WGLM3U8ProcessingSuccessBlock successBlock;
@property (nonatomic, copy) WGLM3U8ProcessingFailureBlock failureBlock;

+ (instancetype)sharedProcessing;

- (void)m3u8ToMp4:(NSString *)m3u8Url success:(WGLM3U8ProcessingSuccessBlock)success failure:(WGLM3U8ProcessingFailureBlock)failure;

@end
