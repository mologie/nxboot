#import "NXUSBDevice.h"
#import "NXBootKit.h"

@implementation NXUSBDevice

- (void)dealloc {
    [self invalidate];
}

- (void)invalidate {
    if (_intf) {
        NXLog(@"USB: Discarding interface of device `%@'", self.name);
        NXCOMCall(self->_intf, Release);
        _intf = NULL;
    }

    if (_notification) {
        NXLog(@"USB: Unsubscribing from notifications for device `%@'", self.name);
        IOObjectRelease(_notification);
        _notification = 0;
    }
}

@end
