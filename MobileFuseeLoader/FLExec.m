/**
 * @file exploits a Tegra X1 CPU's bootloader using Fusée Gelée
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 *
 * This class is a reimplementation of {re}switched's fusee-launcher.py for iOS/IOKit.
 */

#import "FLExec.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>

// TODO split boot into usbOpen, usbSubIntfOpen, bootFusee, usbSubIntfClose, usbClose

// TODO write delegate

// TODO support cancellation

static const UInt8 kTegraInPipe  = 0x81;
static const UInt8 kTegraOutPipe = 0x01;

@interface FLExec ()
@end

@implementation FLExec

- (void)boot {
    assert(self.device != nil && self.delegate != nil);
    FLUSBSubInterface **intf = [self acquireDeviceInterface];
    if (intf) {
        [self execFuseeGelee:intf];
        [self releaseDeviceInterface:intf]; // TODO delay if execFuseeGelee is async
    }
}

- (void)cancel {

}

#pragma mark - Exploit Implementation

- (void)execFuseeGelee:(FLUSBSubInterface **)intf {
    // TODO read the device ID, seems to be required (ReadPipe)

    // TODO contruct the payload (compare fusee and shofl2 layouts)

    // TODO write the payload (WritePipe)

    // TODO do a special control transfer (ControlRequest)
}

#pragma mark - Private

- (FLUSBSubInterface **)acquireDeviceInterface {
    kern_return_t kr;
    io_iterator_t subIntfIter = 0;
    FLUSBSubInterface **intf = NULL;

    kr= FLUSBCall(self.device, USBDeviceOpen);
    if (kr) {
        NSLog(@"ERR: USBDeviceOpen failed with code %08x", kr);
        goto cleanup_error;
    }

    // TODO ensure that this is a configuration which disables charging (that would overload the controller and disconnect the device)
    IOUSBConfigurationDescriptorPtr confDesc;
    kr = FLUSBCall(self.device, GetConfigurationDescriptorPtr, 0, &confDesc);
    if (kr) {
        NSLog(@"ERR: GetConfigurationDescriptorPtr failed with code %08x", kr);
        goto cleanup_error;
    }

    kr = FLUSBCall(self.device, SetConfiguration, confDesc->bConfigurationValue);
    if (kr) {
        NSLog(@"ERR: SetConfiguration failed with code %08x", kr);
        goto cleanup_error;
    }

    IOUSBFindInterfaceRequest subIntfReq = {
        .bInterfaceClass    = kIOUSBFindInterfaceDontCare,
        .bInterfaceSubClass = kIOUSBFindInterfaceDontCare,
        .bInterfaceProtocol = kIOUSBFindInterfaceDontCare,
        .bAlternateSetting  = 0
    };
    kr = FLUSBCall(self.device, CreateInterfaceIterator, &subIntfReq, &subIntfIter);
    if (kr) {
        NSLog(@"ERR: CreateInterfaceIterator failed with code %08x", kr);
        goto cleanup_error;
    }

    // fetch a reference to the first interface and discard the rest
    io_service_t subIntf;
    io_service_t targetIntf = 0;
    while ((subIntf = IOIteratorNext(subIntfIter))) {
        if (!targetIntf) {
            targetIntf = subIntf;
        }
        else {
            IOObjectRelease(subIntf);
        }
    }

    IOCFPlugInInterface **plugInInterface = NULL;
    SInt32 plugInScore;
    kr = IOCreatePlugInInterfaceForService(subIntf,
                                           kIOUSBDeviceUserClientTypeID,
                                           kIOCFPlugInInterfaceID,
                                           &plugInInterface,
                                           &plugInScore);
    if (kr || !plugInInterface) {
        NSLog(@"ERR: Creating interface plugin failed with code %08x", kr);
        goto cleanup_error;
    }
    kr = (*plugInInterface)->QueryInterface(plugInInterface,
                                            CFUUIDGetUUIDBytes(FLUSBSubInterfaceUUID),
                                            (void*)&intf);
    IODestroyPlugInInterface(plugInInterface);
    plugInInterface = NULL;
    if (kr || !intf) {
        NSLog(@"ERR: QueryInterface for device interface failed wiht code %08x", kr);
        goto cleanup_error;
    }

    kr = FLCOMCall(intf, USBInterfaceOpen);
    if (kr) {
        NSLog(@"ERR: USBInterfaceOpen failed with code %08x", kr);
        goto cleanup_error;
    }

    return intf;

cleanup_error:
    if (intf) {
        FLCOMCall(intf, Release);
    }
    if (subIntfIter) {
        IOObjectRelease(subIntfIter);
    }
    FLUSBCall(self.device, USBDeviceClose);
    return NULL;
}

- (void)releaseDeviceInterface:(FLUSBSubInterface **)intf {
    FLCOMCall(intf, USBInterfaceClose);
    FLCOMCall(intf, Release);
    FLUSBCall(self.device, USBDeviceClose);
}

@end
