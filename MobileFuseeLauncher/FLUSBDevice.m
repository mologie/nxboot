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
        NSLog(@"USB: Discarding interface of device `%@'", self.name);
        kr = (*self->_intf)->Release(self->_intf);
        _intf = NULL;
    }

    if (_notification) {
        NSLog(@"USB: Unsubscribing from notifications for device `%@'", self.name);
        IOObjectRelease(_notification);
        _notification = 0;
    }
}

@end
