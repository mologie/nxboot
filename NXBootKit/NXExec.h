/**
 * @file exploits a Tegra X1 CPU's bootloader using Fusée Gelée
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

#define kTegraNintendoSwitchVendorID  0x0955
#define kTegraNintendoSwitchProductID 0x7321

#define NXUSBDeviceInterface      IOUSBDeviceInterface245
#define kNXUSBDeviceInterfaceUUID kIOUSBDeviceInterfaceID245
#define NXUSBSubInterface         IOUSBInterfaceInterface245
#define kNXUSBSubInterfaceUUID    kIOUSBInterfaceInterfaceID245

#define NXCOMCall(OBJECT, METHOD, ...) (*(OBJECT))->METHOD((OBJECT), ##__VA_ARGS__)

struct NXExecDesc {
    NXUSBDeviceInterface **device;
    NXUSBSubInterface **intf;
    UInt8 readRef, writeRef;
};

extern struct NXExecDesc kNXExecDescInvalid;

struct NXExecDesc NXExecAcquireDeviceInterface(NXUSBDeviceInterface **device, NSString **err);
void NXExecReleaseDeviceInterface(struct NXExecDesc const *desc);
BOOL NXExecDesc(struct NXExecDesc const *desc, NSData *relocator, NSData *image, NSString **err);
BOOL NXExec(NXUSBDeviceInterface **device, NSData *relocator, NSData *image, NSString **err);
