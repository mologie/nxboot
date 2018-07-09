/**
 * @file represents one USB device
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import "FLExec.h"

@class FLUSBDeviceEnumerator;

@interface FLUSBDevice : NSObject {
@public
    FLUSBDeviceInterface **_intf;
    UInt32 _locationID;
    io_object_t _notification;
}
@property (weak, nonatomic) FLUSBDeviceEnumerator *parentEnum;
@property (strong, nonatomic) NSString *name;
- (void)invalidate;
@end
