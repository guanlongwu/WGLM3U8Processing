//
//  FFmpegManager.m
//  ZJHVideoProcessing
//
//  Created by ZhangJingHao2345 on 2018/1/29.
//  Copyright © 2018年 ZhangJingHao2345. All rights reserved.
//

#import "FFmpegManager.h"
#import "ffmpeg.h"

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

@interface FFmpegManager () {
    dispatch_semaphore_t _lock;
}
@property (nonatomic, copy) NSString *tsFilePath, *mp4FilePath;   //ts文件路径、mp4待转码文件路径
@property (nonatomic, assign) BOOL isRuning;    //当前有转码任务（可能还没开始转码，准备中或者转码中）
@property (nonatomic, assign) BOOL isConverting;    //转码中状态（真正的转码中状态）
@property (nonatomic, assign) int64_t convertedTime;    //已转码完成的时间
@property (nonatomic, assign) int64_t expectedConvertDuration; //待转码文件的总时长

@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, strong) NSPort *machPort;
@property (nonatomic, strong) NSRunLoop *runLoop;
@end

@implementation FFmpegManager

+ (FFmpegManager *)sharedManager {
    static FFmpegManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _lock = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark - 常驻线程

+ (NSThread *)_networkThread {
    static NSThread *thread = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(_networkThreadMain:) object:nil];
        if ([thread respondsToSelector:@selector(setQualityOfService:)]) {
            thread.qualityOfService = NSQualityOfServiceBackground;
        }
        [thread start];
    });
    return thread;
}

+ (void)_networkThreadMain:(id)object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"com.huya.ffmpeg.convert"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSRunLoopCommonModes];
        [runLoop run];
    }
}

#pragma mark - 转码接口

// 转换视频
- (void)convertWithTSFilePath:(NSString *)tsFilePath mp4FilePath:(NSString *)mp4FilePath processBlock:(void (^)(FFmpegManager *manager, NSString *tsFilePath, float process))processBlock successBlock:(void (^)(FFmpegManager *manager, NSString *tsFilePath, NSString *mp4FilePath))successBlock failureBlock:(void (^)(FFmpegManager *manager, NSString *tsFilePath, NSError *error, FMConvertFailureReason failureReason))failureBlock cancelBlock:(void(^)(FFmpegManager *manager, NSString *tsFilePath))cancelBlock {

    if (self.isRuning) {
        NSLog(@"正在转换,稍后重试!!!!");
        return;
    }
    self.isRuning = YES;
    self.isConverting = NO;
    
    self.tsFilePath = tsFilePath;
    self.mp4FilePath = mp4FilePath;
    self.processBlock = processBlock;
    self.successBlock = successBlock;
    self.failureBlock = failureBlock;
    self.cancelBlock = cancelBlock;
    
    // ffmpeg语法，可根据需求自行更改
    // !#$ 为分割标记符，也可以使用空格代替
    NSString *commandStr = [NSString stringWithFormat:@"ffmpeg!#$-i!#$%@!#$-acodec!#$copy!#$-vcodec!#$copy!#$-bsf:a!#$aac_adtstoasc!#$-y!#$%@", tsFilePath, mp4FilePath];
    
    // 放在子线程运行
//    [self performSelector:@selector(runCmd:) onThread:[FFmpegManager _networkThread] withObject:commandStr waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
    [[[NSThread alloc] initWithTarget:self selector:@selector(runCmd:) object:commandStr] start];
}

// 执行指令
- (void)runCmd:(NSString *)commandStr {
    // 根据 !#$ 将指令分割为指令数组
    NSArray *argv_array = [commandStr componentsSeparatedByString:(@"!#$")];
    // 将OC对象转换为对应的C对象
    int argc = (int)argv_array.count;
    char** argv = (char**)malloc(sizeof(char*)*argc);
    for(int i=0; i < argc; i++) {
        argv[i] = (char*)malloc(sizeof(char)*1024);
        strcpy(argv[i],[[argv_array objectAtIndex:i] UTF8String]);
    }
    
    // 打印日志
    NSString *finalCommand = @"ffmpeg 运行参数:";
    for (NSString *temp in argv_array) {
        finalCommand = [finalCommand stringByAppendingFormat:@"%@",temp];
    }
    NSLog(@"%@",finalCommand);
    
    // 传入指令数及指令数组
    ffmpeg_main(argc,argv);
    
    // 线程已杀死,下方的代码不会执行
}

// 终止转码
- (void)cancelConvert {
    if (self.isRuning) {
        setBreak();
    }
//    cancelProgram();
}

#pragma mark - 回调方法

// 设置总时长
+ (void)setDuration:(long long)time {
    [FFmpegManager sharedManager].expectedConvertDuration = time;
}

// 设置当前已转码成功的时间
+ (void)setCurrentTime:(long long)time {
    FFmpegManager *mgr = [FFmpegManager sharedManager];
    mgr.isConverting = YES;
    mgr.convertedTime = time;
    
    if (mgr.processBlock && mgr.expectedConvertDuration) {
        float process = time/(mgr.expectedConvertDuration * 1.00);
        if (process > 1.0f) {
            NSLog(@"[%@] setProcess:%f, currentTime:%lld, duration:%lld", NSStringFromClass(mgr.class), process, time, mgr.expectedConvertDuration);
            process = 1.0f;
        }
//        NSLog(@"wgl ts ffmpeg process : %f", process);
        dispatch_async(dispatch_get_main_queue(), ^{
            mgr.processBlock(mgr, mgr.tsFilePath, process);
        });
    }
}

// 转换停止
+ (void)stopRuning:(BOOL)isCancel {
    FFmpegManager *mgr = [FFmpegManager sharedManager];
    mgr.isRuning = NO;
    NSLog(@"wgl ts ffmpeg finish : %d", isCancel);
    
    if (isCancel) { //取消
        if (mgr.cancelBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                mgr.cancelBlock(mgr, mgr.tsFilePath);
            });
        }
    }
    else if (!mgr.isConverting) {   // 判断是否开始过
        // 没开始过就设置失败
        NSError *error = [NSError errorWithDomain:@"转换失败,请检查源文件的编码格式!" code:0 userInfo:nil];
        if (mgr.failureBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                mgr.failureBlock(mgr, mgr.tsFilePath, error, FMConvertFailureReasonError);
            });
        }
    }
    else {
        // 转码成功
        if (mgr.successBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                mgr.successBlock(mgr, mgr.tsFilePath, mgr.mp4FilePath);
            });
        }
    }
}

@end
