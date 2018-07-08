/**
 * @file represents one USB device
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

#define FLUSBDeviceInterface      IOUSBDeviceInterface245
#define kFLUSBDeviceInterfaceUUID kIOUSBDeviceInterfaceID245
#define FLUSBSubInterface         IOUSBInterfaceInterface245
#define kFLUSBSubInterfaceUUID    kIOUSBInterfaceInterfaceID245

#define FLCOMCall(OBJECT, METHOD, ...) (*(OBJECT))->METHOD((OBJECT), ##__VA_ARGS__)
#define FLUSBCall(DEVICE, METHOD, ...) FLCOMCall((DEVICE)->_intf, METHOD, ##__VA_ARGS__)

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
