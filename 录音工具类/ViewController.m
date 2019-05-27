//
//  ViewController.m
//  录音工具类
//
//  Created by majianghai on 2019/5/27.
//  Copyright © 2019 com.cmcmid. All rights reserved.
//

#import "ViewController.h"
#import "OVSVADAQRecorder.h"

@interface ViewController ()
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) OVSVADAQRecorder *recordTool;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.recordTool = [OVSVADAQRecorder shared];
}


/// 开始说话
- (IBAction)talkBtnClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    
    if (sender.selected) {
        NSLog(@"开始录音");
        self.isRecording = YES;
        [self.recordTool start];
        [sender setTitle:@"点击结束说话" forState:UIControlStateNormal];
    } else {
        NSLog(@"-----结束录音1");
        self.isRecording = NO;
        [self.recordTool stop];
        NSLog(@"-----结束录音2");
        [sender setTitle:@"点击开始说话" forState:UIControlStateNormal];
    }
}

- (void)ovsAQRecorder:(OVSVADAQRecorder *)recorder didRecivedBuffer:(Byte *)buffer length:(NSInteger)length {
    NSLog(@"-----------length = %ld", (long)length);
    NSLog(@"-----------buffer = %s", buffer);
    
    if (self.isRecording) {
//        [[OVSASREngine shared] inputG7221AudioBuffer:buffer
//                                              length:length
//                                               index:self.bufferIndex++
//                                             request:self.reqType];
    } else {
//        [[OVSASREngine shared] inputG7221AudioBuffer:buffer length:length index:-1 request:self.reqType];
//        self.bufferIndex = 0;
    }
    
}

- (void)ovsAQRecorder:(OVSVADAQRecorder *)recorder finishWithError:(NSError *)error {
    NSLog(@"-----------error = %@", error);
}

@end
