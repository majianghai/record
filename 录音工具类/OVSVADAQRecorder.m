//
//  OVSVADAQRecorder.m
//  OVSVADEngine
//
//  Created by haijie shi on 22/09/2017.
//  Copyright © 2017 Orion Star. All rights reserved.
//

#import "OVSVADAQRecorder.h"
#import <AVFoundation/AVFoundation.h>

typedef struct OVSAQCallbackStruct {
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef queue;
    AudioQueueBufferRef mBuffers[kNumberAudioQueueBuffers];
    AudioFileID outputFile;

    unsigned long frameSize;
    long long recPtr;
    int run;
} OVSAQCallbackStruct;


@interface OVSVADAQRecorder ()

@property (nonatomic, assign) OVSAQCallbackStruct aqc;

- (void)processAudioBuffer:(AudioQueueBufferRef)buffer withQueue:(AudioQueueRef)queue;

@end

static void AQInputCallback(void *inUserData, AudioQueueRef inAudioQueue, AudioQueueBufferRef inBuffer,
    const AudioTimeStamp *inStartTime, UInt32 nNumPackets, const AudioStreamPacketDescription *inPacketDesc) {
    OVSVADAQRecorder *engine = (__bridge OVSVADAQRecorder *)inUserData;
    if (inBuffer->mAudioDataByteSize > 0) {
        [engine processAudioBuffer:inBuffer withQueue:inAudioQueue];
    }

    if (engine.aqc.run) {
        AudioQueueEnqueueBuffer(engine.aqc.queue, inBuffer, 0, NULL);
    }
}


@implementation OVSVADAQRecorder

- (void)dealloc {
    AudioQueueStop(_aqc.queue, true);
    _aqc.run = 0;
    AudioQueueDispose(_aqc.queue, true);
}

+ (instancetype)shared {
    static OVSVADAQRecorder *recorder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recorder = [[OVSVADAQRecorder alloc] init];
    });
    return recorder;
}

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)start {
    NSLog(@"OVSAQRecorder--->mainThread:%@,current thread:%@", [NSThread mainThread], [NSThread currentThread]);
    // 开启录音通道
    NSError *error = nil;
    //设置audio session的category
    int ret = [[AVAudioSession sharedInstance]
        setCategory:AVAudioSessionCategoryPlayAndRecord
              error:
                  &
                  error]; //注意，这里选的是AVAudioSessionCategoryPlayAndRecord参数，如果只需要录音，就选择Record就可以了，如果需要录音和播放，则选择PlayAndRecord，这个很重要
    if (!ret) {
        NSLog(@"设置声音环境失败");
        if ([self.delegate respondsToSelector:@selector(ovsAQRecorder:finishWithError:)]) {
            [self.delegate ovsAQRecorder:self finishWithError:error];
        }
        return;
    }
    //启用audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret) {
        NSLog(@"启动失败");
        if ([self.delegate respondsToSelector:@selector(ovsAQRecorder:finishWithError:)]) {
            [self.delegate ovsAQRecorder:self finishWithError:error];
        }
        return;
    }

    // 初始化 AudioFormat
    _aqc.mDataFormat.mSampleRate = DEFAULT_SAMPLE_RATE;
    _aqc.mDataFormat.mFramesPerPacket = 1;
    //每个通道里，一帧采集的bit数目
    _aqc.mDataFormat.mChannelsPerFrame = DEFAULT_CHANNELS;
    //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
    _aqc.mDataFormat.mBitsPerChannel = DEFAULT_SAMPLE_LENGTH;
    _aqc.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    _aqc.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;

    //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
    //至于为什么要这样。。。不知道。。。
    _aqc.mDataFormat.mBytesPerFrame = (_aqc.mDataFormat.mBitsPerChannel / 8) * _aqc.mDataFormat.mChannelsPerFrame;
    _aqc.mDataFormat.mBytesPerPacket = _aqc.mDataFormat.mBytesPerFrame;

    //初始化音频输入队列
    AudioQueueNewInput(&_aqc.mDataFormat, AQInputCallback, (__bridge void *)(self), NULL, NULL, 0, &_aqc.queue);

    //计算估算的缓存区大小
    //返回大于或者等于指定表达式的最小整数
    //    int frames = (int)ceil(kDefaultBufferDurationSeconds * _aqc.mDataFormat.mSampleRate);
    //    缓冲区大小在这里设置，这个很重要，在这里设置的缓冲区有多大，那么在回调函数的时候得到的inbuffer的大小就是多大。
    //    int bufferByteSize = frames * _aqc.mDataFormat.mBytesPerFrame;
    //    NSLog(@"录音缓冲区大小:%d", bufferByteSize);
    int bufferByteSize = 720;

    //创建缓冲器
    for (int i = 0; i < kNumberAudioQueueBuffers; i++) {
        OSStatus status = AudioQueueAllocateBuffer(_aqc.queue, bufferByteSize, &_aqc.mBuffers[i]);
        if (status != noErr) {
            AudioQueueDispose(_aqc.queue, true);
            _aqc.queue = NULL;
            break;
        }
        //将 _audioBuffers[i] 添加到队列中
        AudioQueueEnqueueBuffer(_aqc.queue, _aqc.mBuffers[i], 0, NULL);
    }

    _aqc.recPtr = 0;
    _aqc.run = 1;

    // 开始录音
    if (_aqc.queue) {
        AudioQueueStart(_aqc.queue, NULL);
        NSLog(@"OVS AQ Recorder-> 开始录音");
    } else {
        if ([self.delegate respondsToSelector:@selector(ovsAQRecorder:finishWithError:)]) {
            [self.delegate ovsAQRecorder:self
                         finishWithError:[NSError errorWithDomain:@"OVS AQ Recorder"
                                                             code:-1
                                                         userInfo:@{
                                                             NSLocalizedDescriptionKey : @"录音初始化错误"
                                                         }]];
        }
        NSLog(@"OVS AQ Recorder-> 录音初始化错误");
    }
}

- (void)stop {
    _aqc.run = 0;

    AudioQueueStop(_aqc.queue, true);
    if ([self.delegate respondsToSelector:@selector(ovsAQRecorder:finishWithError:)]) {
        [self.delegate ovsAQRecorder:self finishWithError:nil];
    }
}

#pragma mark - Private

- (void)processAudioBuffer:(AudioQueueBufferRef)inBuffer withQueue:(AudioQueueRef)queue {

    Byte *data = (Byte *)malloc(inBuffer->mAudioDataByteSize);
    memset(data, 0, inBuffer->mAudioDataByteSize);
    memcpy(data, inBuffer->mAudioData, inBuffer->mAudioDataByteSize);
    if (data != NULL) {

        if ([self.delegate respondsToSelector:@selector(ovsAQRecorder:didRecivedBuffer:length:)]) {
            [self.delegate ovsAQRecorder:self didRecivedBuffer:data length:inBuffer->mAudioDataByteSize];
        }
    }

    free(data);
}

@end
