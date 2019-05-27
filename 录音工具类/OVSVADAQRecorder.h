//
//  OVSVADAQRecorder.h
//  OVSVADEngine

#import <Foundation/Foundation.h>

#define DEFAULT_CHANNELS (1)
#define DEFAULT_SAMPLE_RATE (16000)
#define DEFAULT_SAMPLE_LENGTH (16)
#define DEFAULT_DURATION_TIME (10)

#define kNumberAudioQueueBuffers 3 // 定义了三个缓冲区

@class OVSVADAQRecorder;

@protocol OVSAQRecorderDelegate <NSObject>

- (void)ovsAQRecorder:(OVSVADAQRecorder *)recorder didRecivedBuffer:(Byte *)buffer length:(NSInteger)length;
- (void)ovsAQRecorder:(OVSVADAQRecorder *)recorder finishWithError:(NSError *)error;

@end


@interface OVSVADAQRecorder : NSObject

@property (nonatomic, weak) id<OVSAQRecorderDelegate> delegate;

+ (instancetype)shared;

- (void)start;
- (void)stop;

@end
