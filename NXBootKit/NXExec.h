#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <objc/objc.h> // BOOL

#define kTegraX1VendorID  0x0955u
#define kTegraX1ProductID 0x7321u

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

@class NXUSBDevice;
BOOL NXExec(NXUSBDevice *device, NSData *relocator, NSData *image, NSString **err);
