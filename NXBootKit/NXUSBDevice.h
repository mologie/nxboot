/**
 * @file represents one USB device
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import "NXExec.h"

@class NXUSBDeviceEnumerator;

@interface NXUSBDevice : NSObject {
@public
    NXUSBDeviceInterface **_intf;
    UInt32 _locationID;
    io_object_t _notification;
}
@property (weak, nonatomic) NXUSBDeviceEnumerator *parentEnum;
@property (strong, nonatomic) NSString *name;
- (void)invalidate;
@end
