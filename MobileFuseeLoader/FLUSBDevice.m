/**
 * @file represents one USB device
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "FLUSBDevice.h"

@implementation FLUSBDevice

- (void)dealloc {
    [self invalidate];
}

- (void)invalidate {
    kern_return_t kr;

    if (_intf) {
        kr = FLUSBCall(self, Release);
        _intf = NULL;
    }

    if (_notification) {
        IOObjectRelease(_notification);
        _notification = 0;
    }
}

@end
