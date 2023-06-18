/**
 * @file uses Hekate's payload storage for customizing boot behavior
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "NXHekateCustomizer.h"
#import "NXBootKit.h"

// Hekate's payload config starts at 0x94 and is initialized to zero. It is
// immediately followed by the magic value 'ICTC' and three version digits.
#define BOOT_CFG_AUTOBOOT_EN (1 << 0)
#define BOOT_CFG_FROM_LAUNCH (1 << 1)
#define BOOT_CFG_FROM_ID     (1 << 2)
#define EXTRA_CFG_NYX_UMS    (1 << 5)
typedef struct {
    UInt8 BootCfg;
    UInt8 AutoBoot;
    UInt8 AutoBootList;
    UInt8 ExtraCfg;
    union {
        UInt8 UMS;
        struct {
            char ID[8];
            char EmuMMCPath[120];
        } Boot;
    } XtStr;
} __attribute__((packed)) NXHekatePayloadConfig;
static UInt32 const kNXHekatePayloadConfigOffset = 0x94;
static_assert(sizeof(NXHekatePayloadConfig) == 132, "unexpected size of NXHekatePayloadConfig");
static char const kNXHekateMagic[4] = {'I','C','T','C'};

@implementation NXHekateCustomizer

- (instancetype)initWithPayload:(NSData *)payload {
    if (self = [super init]) {
        self.payload = payload;
    }
    return self;
}

- (BOOL)isPayloadSupported {
    if (self.payload.length < 0x1000) {
        // The payload is too small to be Hekate. The remainder of this object
        // assumes that we are dealing with a Hekate payload and have sufficient
        // space to read/write without further bounds checking.
        NXLog(@"Hekate: Rejecting payload smaller than 4KiB");
        return NO;
    }
    
    // Ensure that storage area is zero
    char const *b = (char const *)self.payload.bytes + kNXHekatePayloadConfigOffset;
    for (unsigned i = 0; i < sizeof(NXHekatePayloadConfig); i++) {
        if (b[i] != 0) {
            NXLog(@"Hekate: Unexpected non-zero storage byte at %u", i);
            return NO;
        }
    }
    
    // Compare magic value
    b += sizeof(NXHekatePayloadConfig);
    char major = b[4];
    if (memcmp(b, kNXHekateMagic, sizeof(kNXHekateMagic)) != 0) {
        NXLog(@"Hekate: Version %d changed the magic header and is not supported", major);
        return NO;
    }
    
    return YES;
}

- (NSString *)version {
    assert(self.payloadSupported);
    char const *v = (char const *)self.payload.bytes +
        kNXHekatePayloadConfigOffset +
        sizeof(NXHekatePayloadConfig) +
        sizeof(kNXHekateMagic);
    return [NSString stringWithFormat:@"%c.%c.%c", v[0], v[1], v[2]];
}

- (NSData *)commitToImage {
    assert(self.payloadSupported);
    
    NSMutableData *payload = [self.payload mutableCopy];
    NXHekatePayloadConfig *cfg = (NXHekatePayloadConfig *)
        ((char *)payload.mutableBytes + kNXHekatePayloadConfigOffset);
    
    switch (self.bootTarget) {
        case NXHekateBootTargetMenu:
            cfg->BootCfg |= BOOT_CFG_AUTOBOOT_EN;
            cfg->AutoBoot = 0;
            NXLog(@"Hekate: Auto-boot disabled");
            break;
        case NXHekateBootTargetID:
            cfg->BootCfg |= BOOT_CFG_AUTOBOOT_EN | BOOT_CFG_FROM_ID;
            cfg->AutoBoot = 0;
            strncpy(cfg->XtStr.Boot.ID, self.bootID.UTF8String, 8);
            cfg->XtStr.Boot.ID[7] = 0;
            NXLog(@"Hekate: Auto-boot enabled with ID `%s'", cfg->XtStr.Boot.ID);
            break;
        case NXHekateBootTargetIndex:
            cfg->BootCfg |= BOOT_CFG_AUTOBOOT_EN;
            cfg->AutoBoot = (UInt8)self.bootIndex;
            NXLog(@"Hekate: Auto-boot enabled with index %ld", (long)self.bootIndex);
            break;
        case NXHekateBootTargetUMS:
            cfg->BootCfg |= BOOT_CFG_AUTOBOOT_EN;
            cfg->AutoBoot = 0;
            cfg->ExtraCfg |= EXTRA_CFG_NYX_UMS;
            cfg->XtStr.UMS = (UInt8)self.umsTarget;
            NXLog(@"Hekate: UMS enabled with target %ld", (long)self.umsTarget);
            break;
    }
    
    if (self.logFlag) {
        cfg->BootCfg |= BOOT_CFG_FROM_LAUNCH;
    }
    
    return payload;
}

@end
