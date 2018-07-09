/**
 * @file exploits a Tegra X1 CPU's bootloader using Fusée Gelée
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

#define FLUSBDeviceInterface      IOUSBDeviceInterface245
#define kFLUSBDeviceInterfaceUUID kIOUSBDeviceInterfaceID245
#define FLUSBSubInterface         IOUSBInterfaceInterface245
#define kFLUSBSubInterfaceUUID    kIOUSBInterfaceInterfaceID245

#define FLCOMCall(OBJECT, METHOD, ...) (*(OBJECT))->METHOD((OBJECT), ##__VA_ARGS__)

BOOL FLExec(FLUSBDeviceInterface **device, NSData *relocator, NSData *image, NSString **err);
