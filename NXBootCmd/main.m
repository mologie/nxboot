/**
 * @file command-line tool for RCM exploitation of the Nintendo Switch
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>

// inline source files for trivial, single-file compilation. sorry!
#import "../NXBoot/FLExec.m"
#import "../NXBoot/FLUSBDevice.m"
#import "../NXBoot/FLUSBDeviceEnumerator.m"
#import "../NXBoot/NSData+FLHexEncoding.m"

@interface NXBoot : NSObject <FLUSBDeviceEnumeratorDelegate>
@property (strong, nonatomic) NSData *relocator;
@property (strong, nonatomic) NSData *image;
@property (strong, nonatomic) FLUSBDeviceEnumerator *usbEnum;
@end

@implementation NXBoot

- (void)start {
    self.usbEnum = [[FLUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum addFilterForVendorID:kTegraNintendoSwitchVendorID productID:kTegraNintendoSwitchProductID];
    [self.usbEnum start];
}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceConnected:(FLUSBDevice *)device {
    NSString *err = nil;
    if (FLExec(device->_intf, self.relocator, self.image, &err)) {
        NSLog(@"CMD: FLExec succeeded");
    }
    else {
        NSLog(@"CMD: FLExec failed: %@", err);
    }
}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(FLUSBDevice *)device {}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSString *relocatorPath = @"/jb/share/flexec/intermezzo.bin";
        NSString *imagePath = @"/jb/share/flexec/fusee.bin";

        if (argc == 3) {
            relocatorPath = [NSString stringWithUTF8String:argv[1]];
            imagePath = [NSString stringWithUTF8String:argv[2]];
        }

        NSLog(@"CMD: Using relocator %@ and image %@", relocatorPath, imagePath);
        NXBoot *cmdTool = [[NXBoot alloc] init];

        cmdTool.relocator = [NSData dataWithContentsOfFile:relocatorPath];
        if (cmdTool.relocator == nil) {
            NSLog(@"ERR: Failed to load relocator");
            return 1;
        }

        cmdTool.image = [NSData dataWithContentsOfFile:imagePath];
        if (cmdTool.image == nil) {
            NSLog(@"ERR: Failed to load image");
            return 1;
        }

        [cmdTool start];
        CFRunLoopRun();

        return 0;
    }
}
