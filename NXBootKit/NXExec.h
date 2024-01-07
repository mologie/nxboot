#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <NXBootKit/NXVisibility.h>
#import <objc/objc.h> // BOOL

#define kTegraX1VendorID  0x0955u
#define kTegraX1ProductID 0x7321u

#define NXUSBDeviceInterface      IOUSBDeviceInterface245
#define kNXUSBDeviceInterfaceUUID kIOUSBDeviceInterfaceID245
#define NXUSBSubInterface         IOUSBInterfaceInterface245
#define kNXUSBSubInterfaceUUID    kIOUSBInterfaceInterfaceID245

#define NXCOMCall(OBJECT, METHOD, ...) (*(OBJECT))->METHOD((OBJECT), ##__VA_ARGS__)

NXBOOTKIT_PUBLIC extern size_t const NXMaxFuseePayloadSize;

struct NXExecDesc {
    NXUSBDeviceInterface **device;
    NXUSBSubInterface **intf;
    UInt8 readRef, writeRef;
};

extern struct NXExecDesc kNXExecDescInvalid;

NXBOOTKIT_PUBLIC struct NXExecDesc NXExecAcquireDeviceInterface(NXUSBDeviceInterface **device, NSString **err);
NXBOOTKIT_PUBLIC void NXExecReleaseDeviceInterface(struct NXExecDesc const *desc);
NXBOOTKIT_PUBLIC BOOL NXExecDesc(struct NXExecDesc const *desc, NSData *relocator, NSData *image, NSString **err);

@class NXUSBDevice;
NXBOOTKIT_PUBLIC BOOL NXExec(NXUSBDevice *device, NSData *relocator, NSData *image, NSString **err);
