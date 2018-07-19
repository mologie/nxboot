/**
 * @file command-line tool for RCM exploitation of the Nintendo Switch
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import "NXBootKit.h"
#import "NXExec.h"
#import "NXUSBDevice.h"
#import "NXUSBDeviceEnumerator.h"

@interface NXBoot : NSObject <NXUSBDeviceEnumeratorDelegate>
@property (strong, nonatomic) NSData *relocator;
@property (strong, nonatomic) NSData *image;
@property (strong, nonatomic) NXUSBDeviceEnumerator *usbEnum;
@property (assign, nonatomic) BOOL daemon; // keep running after handling a device
@property (assign, nonatomic) BOOL keepReading;
@end

@implementation NXBoot

- (void)start {
    self.usbEnum = [[NXUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum addFilterForVendorID:kTegraNintendoSwitchVendorID productID:kTegraNintendoSwitchProductID];
    [self.usbEnum start];
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceConnected:(NXUSBDevice *)device {
    kern_return_t kr;
    NSString *err = nil;
    struct NXExecDesc desc = NXExecAcquireDeviceInterface(device->_intf, &err);
    if (desc.intf) {
        if (NXExecDesc(&desc, self.relocator, self.image, &err)) {
            if (self.keepReading) {
                fprintf(stderr, "success: payload was run, will continue to read data to stdout...\n");
                UInt32 btransf;
                char rdbuf[0x1000];
                while (true) {
                    btransf = sizeof(rdbuf);
                    kr = NXCOMCall(desc.intf, ReadPipeTO, desc.readRef, rdbuf, &btransf, 1000, 1000);
                    if (kr) {
                        fprintf(stderr, "Failed to read after successful payload execution with code %08x.\n", kr);
                        fprintf(stderr, "This is not an error if the RCM payload deliberately terminated the USB connection. Exiting.\n");
                        break;
                    }
                    fwrite(rdbuf, btransf, 1, stdout);
                }
            }
            else {
                fprintf(stderr, "success: payload was run. fair winds!\n");
            }
        }
        else {
            fprintf(stderr, "error: NXExec failed: %s\n", err.UTF8String);
        }
        NXExecReleaseDeviceInterface(&desc);
    }
    else {
        fprintf(stderr, "error: could not acquire USB device handle: %s\n", err.UTF8String);
    }
    if (self.keepReading || !self.daemon) {
        CFRunLoopStop(CFRunLoopGetMain());
    }
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(NXUSBDevice *)device {
    // unused
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {
    // error was already printed by implementation
}

@end

static void printHelp() {
    fprintf(stderr, "usage: nxboot [-v] [-d|-r] <relocator> <payload>\n");
    fprintf(stderr, "  -v: enable debug logging\n");
    fprintf(stderr, "  -d: daemon mode, don't stop after handling the first device\n");
    fprintf(stderr, "  -r: read more data from payload (cannot be used with -d)\n\n");
    fprintf(stderr, "for updates visit https://mologie.github.io/nxboot/\n");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NXBoot *cmdTool = [[NXBoot alloc] init];
        NSString *relocatorPath = nil;
        NSString *imagePath = nil;

        NXBootKitDebugEnabled = NO;

        fprintf(stderr, "nxboot %s build %d\n", NXBOOT_VERSION, NXBOOT_BUILDNO);

        for (int i = 1, pos = 0; i < argc; i++) {
            if (argv[i][0] == '-') {
                if (strlen(argv[i]) != 2) {
                    fprintf(stderr, "error: unknown argument -%s\n", argv[i]);
                    return 1;
                }
                switch (argv[i][1]) {
                    case 'h':
                        fprintf(stderr, "Copyright 2018 Oliver Kuckertz <oliver.kuckertz@mologie.de>\n");
                        printHelp();
                        return 0;
                    case 'v':
                        NXBootKitDebugEnabled = YES;
                        break;
                    case 'd':
                        if (cmdTool.keepReading) {
                            fprintf(stderr, "error: -d cannot be used with -r\n");
                            return 1;
                        }
                        cmdTool.daemon = YES;
                        break;
                    case 'r':
                        if (cmdTool.daemon) {
                            fprintf(stderr, "error: -r cannot be used with -d\n");
                            return 1;
                        }
                        cmdTool.keepReading = YES;
                        break;
                    default:
                        fprintf(stderr, "error: unknown argument -%s\n", argv[i]);
                        return 1;
                }
            }
            else {
                switch (pos) {
                    case 0:
                        relocatorPath = [NSString stringWithUTF8String:argv[i]];
                        break;
                    case 1:
                        imagePath = [NSString stringWithUTF8String:argv[i]];
                        break;
                    default:
                        fprintf(stderr, "error: too many positional arguments\n");
                        return 1;
                }
                pos++;
            }
        }

        if (!relocatorPath || !imagePath) {
            printHelp();
            return 1;
        }

        NXLog(@"CMD: Using relocator %@ and image %@", relocatorPath, imagePath);

        cmdTool.relocator = [NSData dataWithContentsOfFile:relocatorPath];
        if (cmdTool.relocator == nil) {
            fprintf(stderr, "error: failed to load relocator\n");
            return 1;
        }

        cmdTool.image = [NSData dataWithContentsOfFile:imagePath];
        if (cmdTool.image == nil) {
            fprintf(stderr, "error: failed to load payload\n");
            return 1;
        }

        [cmdTool start];
        CFRunLoopRun();

        return 0;
    }
}
