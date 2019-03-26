//
//  WGLM3U8Entity.h
//  WGLM3U8Processing
//
//  Created by wugl on 2019/3/25.
//  Copyright © 2019年 WGLKit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WGLTSEntity : NSObject
@property (nonatomic, assign) uint64_t index;
@property (nonatomic, assign) uint64_t duration;
@property (nonatomic, copy) NSString *url;
@end


@interface WGLM3U8Entity : NSObject
@property (nonatomic, strong) NSMutableArray <WGLTSEntity *> *playList;
@end
