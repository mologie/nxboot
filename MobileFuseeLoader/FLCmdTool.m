//
//  FLCmdTool.m
//  MobileFuseeLoader
//
//  Created by Oliver Kuckertz on 07.07.18.
//  Copyright © 2018 Oliver Kuckertz. All rights reserved.
//

#import "FLCmdTool.h"
#import "FLExec.h"
#import "FLUSBDeviceEnumerator.h"

@interface FLCmdTool () <FLUSBDeviceEnumeratorDelegate>
@property (strong, nonatomic) FLUSBDeviceEnumerator *usbEnum;
@end

@implementation FLCmdTool

- (void)start {
    self.usbEnum = [[FLUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum addFilterForVendorID:0x0955 productID:0x7321];
    [self.usbEnum start];
}

#pragma mark - FLUSBDeviceEnumeratorDelegate

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceConnected:(FLUSBDevice *)device {
    NSString *err = nil;
    if (FLExec(device, self.relocator, self.image, &err)) {
        NSLog(@"CMD: FLExec succeeded");
    }
    else {
        NSLog(@"CMD: FLExec failed: %@", err);
    }
}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(FLUSBDevice *)device {}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {}

@end
