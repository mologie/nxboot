/**
 * @file main.m
 * @brief command-line tool for RCM exploitation of the Nintendo Switch
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import <signal.h>
#import "NXBootKit.h"
#import "NXExec.h"
#import "NXHekateCustomizer.h"
#import "NXUSBDevice.h"
#import "NXUSBDeviceEnumerator.h"

#define ESC_RED   "\033[1;31m"
#define ESC_GREEN "\033[1;32m"
#define ESC       "\033[0m"
#define ESC_LN    ESC "\n"

#define COPYRIGHT_STR "Copyright 2018-2024 Oliver Kuckertz <oliver.kuckertz@mologie.de>"
#define LICENSE_STR   "Licensed under the GPLv3. https://github.com/mologie/nxboot#license"

static volatile sig_atomic_t gTerm = 0;

@interface NXBoot : NSObject <NXUSBDeviceEnumeratorDelegate>

@property (strong, nonatomic) NSData *relocator;
@property (strong, nonatomic) NSData *image;
@property (strong, nonatomic) NXUSBDeviceEnumerator *usbEnum;
@property (assign, nonatomic) BOOL daemon; // keep running after handling a device
@property (assign, nonatomic) BOOL keepReading;
@property (assign, nonatomic) BOOL lastBootFailed;

@end

@implementation NXBoot

- (void)start {
    self.usbEnum = [[NXUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum setFilterForVendorID:kTegraX1VendorID productID:kTegraX1ProductID];
    [self.usbEnum start];
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceConnected:(NXUSBDevice *)device {
    kern_return_t kr;
    NSString *err = nil;

    struct NXExecDesc desc = NXExecAcquireDeviceInterface(device->_intf, &err);

    if (desc.intf) {
        if (NXExecDesc(&desc, self.relocator, self.image, &err)) {
            self.lastBootFailed = NO;
            if (self.keepReading) {
                fprintf(stderr, ESC_GREEN "success: payload was run, will continue to read from EP1 to stdout..." ESC_LN);
                UInt32 btransf;
                char rdbuf[0x1000];
                while (!gTerm) {
                    btransf = sizeof(rdbuf);
                    kr = NXCOMCall(desc.intf, ReadPipeTO, desc.readRef, rdbuf, &btransf, 1000, 1000);
                    if (kr == 0xE0004051) {
                        // bulk read error, expected
                        fprintf(stderr, ESC_GREEN "success: USB EP1 bulk stream was terminated, exiting" ESC_LN);
                        break;
                    }
                    if (kr) {
                        fprintf(stderr, "Failed to read after successful payload execution with code %08x.\n", kr);
                        fprintf(stderr, "This is not an error if the RCM payload deliberately terminated the USB connection. Exiting.\n");
                        break;
                    }
                    fwrite(rdbuf, btransf, 1, stdout);
                }
                if (gTerm) {
                    fprintf(stderr, ESC_GREEN "error: USB EP1 read operation was interrupted" ESC_LN);
                }
            }
            else if (self.daemon) {
                fprintf(stderr, ESC_GREEN "success: payload was run" ESC_LN);
            }
            else {
                fprintf(stderr, ESC_GREEN "success: payload was run. exiting, fair winds!" ESC_LN);
            }
        }
        else {
            self.lastBootFailed = YES;
            fprintf(stderr, ESC_RED "error: NXExec failed: %s" ESC_LN, err.UTF8String);
        }
        NXExecReleaseDeviceInterface(&desc);
    }
    else {
        self.lastBootFailed = YES;
        fprintf(stderr, ESC_RED "error: could not acquire USB device handle: %s" ESC_LN, err.UTF8String);
    }

    if (self.daemon) {
        fprintf(stderr, "waiting for next connection...\n");
    }
    else {
        CFRunLoopStop(CFRunLoopGetMain());
    }
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(NXUSBDevice *)device {
    // unused
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {
    // error was already printed by implementation
}

@end

static void printUsage(void) {
    fprintf(stderr,
            "usage: nxboot [-v] [-d|-k] [-r <relocator>] [--hekate <cmds>] <payload>\n"
            "  -v: enable verbose debug output\n"
            "  -d: daemon mode, don't stop after handling the first device\n"
            "  -k: read data from USB EP1 to stdout after payload execution (conflicts with -d)\n"
            "  -r: use a custom relocator (default: embedded Fusée/intermezzo)\n"
            "\n"
            "advanced Hekate options:\n"
            "  --hekate menu: enter Hekate menu regardless of autoboot setting\n"
            "  --hekate id <id>: boot entry with matching 'id' value\n"
            "  --hekate entry <number>: boot hekate_ipl.ini entry with matching index\n"
            "  --hekate ums sd|[emu-]boot0|[emu-]boot1|[emu-]gpp: start USB storage host\n"
            "  --hekate-log: display launch log\n"
            "\n"
            "examples:\n"
            "  nxboot hekate_ctcaer_6.0.4.bin (boots Hekate)\n"
            "  nxboot --hekate ums sd hekate_ctcaer_6.0.4.bin (boots Hekate into UMS SD mode)\n"
            "\n"
            "for updates visit: https://mologie.github.io/nxboot/\n");
}

static void printHelp(void) {
    fprintf(stderr,
            "\n"
            "NXBoot is a Fusée/ShofEL2 implementation for macOS and iOS.\n"
            "It supports any Fusée and Coreboot/CBFS payload.\n"
            "This application does not come with payloads, so please provide your own.\n"
            "\n"
            COPYRIGHT_STR "\n"
            LICENSE_STR "\n\n");
    printUsage();
}

static void onSignal(int sig) {
    gTerm = 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        NXLog(@"CMD: Got signal %d, stopping main run loop", sig);
        CFRunLoopStop(CFRunLoopGetMain());
    });
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NXBootKitDebugEnabled = NO;

        NXBoot *cmdTool = [[NXBoot alloc] init];
        NXHekateCustomizer *hekate = [[NXHekateCustomizer alloc] init];
        BOOL hekateExpected = NO;
        BOOL hekateBootConfigured = NO;

        fprintf(stderr, "nxboot %s build %d\n", NXBOOT_VERSION, NXBOOT_BUILDNO);

        for (int i = 1, pos = 0; i < argc; i++) {
            if (argv[i][0] == '-') {
                if (strlen(argv[i]) < 2) {
                    fprintf(stderr, ESC_RED "error: incomplete argument %s" ESC_LN, argv[i]);
                    printUsage();
                    return 1;
                }
                char const* a = argv[i] + 1;
                bool longarg = false;
                char c;
                while (*a && !longarg) switch (c = *a++) {
                    case 'h': {
                        printHelp();
                        return 0;
                    }
                    case 'v': {
                        NXBootKitDebugEnabled = YES;
                        break;
                    }
                    case 'd': {
                        if (cmdTool.keepReading) {
                            fprintf(stderr, ESC_RED "error: -d cannot be used with -k" ESC_LN);
                            printUsage();
                            return 1;
                        }
                        cmdTool.daemon = YES;
                        break;
                    }
                    case 'k': {
                        if (cmdTool.daemon) {
                            fprintf(stderr, ESC_RED "error: -d cannot be used with -k" ESC_LN);
                            printUsage();
                            return 1;
                        }
                        cmdTool.keepReading = YES;
                        break;
                    }
                    case 'r': {
                        i++;
                        if (i < argc) {
                            NSString *path = [NSString stringWithUTF8String:argv[i]];
                            NXLog(@"CMD: Using relocator %@", path);
                            cmdTool.relocator = [NSData dataWithContentsOfFile:path];
                            if (cmdTool.relocator == nil) {
                                fprintf(stderr, ESC_RED "error: failed to load relocator" ESC_LN);
                                return 1;
                            }
                        }
                        else {
                            fprintf(stderr, ESC_RED "error: -r requires an argument" ESC_LN);
                            printUsage();
                            return 1;
                        }
                        break;
                    }
                    case '-': {
                        if (strcmp(a, "help") == 0) {
                            printHelp();
                            return 0;
                        }
                        else if (strcmp(a, "hekate") == 0) {
                            hekateExpected = YES;
                            i++;
                            if (hekateBootConfigured) {
                                fprintf(stderr, ESC_RED "error: only one --hekate boot command can be set" ESC_LN);
                                printUsage();
                                return 1;
                            }
                            if (i < argc) {
                                char const* cmd = argv[i];
                                if (strcmp(cmd, "menu") == 0) {
                                    hekate.bootTarget = NXHekateBootTargetMenu;
                                }
                                else if (strcmp(cmd, "id") == 0) {
                                    hekate.bootTarget = NXHekateBootTargetID;
                                    i++;
                                    if (i < argc) {
                                        hekate.bootID = [NSString stringWithUTF8String:argv[i]];
                                        if (hekate.bootID.length == 0 || hekate.bootID.length > 7) {
                                            fprintf(stderr, ESC_RED "error: --hekate id argument must be at least 1 and at most 7 characters long" ESC_LN);
                                            printUsage();
                                            return 1;
                                        }
                                    }
                                    else {
                                        fprintf(stderr, ESC_RED "error: --hekate id requires an argument" ESC_LN);
                                        printUsage();
                                        return 1;
                                    }
                                }
                                else if (strcmp(cmd, "entry") == 0) {
                                    hekate.bootTarget = NXHekateBootTargetIndex;
                                    i++;
                                    if (i < argc) {
                                        NSString *entry = [NSString stringWithUTF8String:argv[i]];
                                        hekate.bootIndex = [entry integerValue];
                                        if (hekate.bootIndex <= 0 || hekate.bootIndex > 0xFF) {
                                            fprintf(stderr, ESC_RED "error: --hekate entry requires an integer argument in 1-255" ESC_LN);
                                            printUsage();
                                            return 1;
                                        }
                                    }
                                    else {
                                        fprintf(stderr, ESC_RED "error: --hekate entry requires an argument" ESC_LN);
                                        printUsage();
                                        return 1;
                                    }
                                }
                                else if (strcmp(cmd, "ums") == 0) {
                                    hekate.bootTarget = NXHekateBootTargetUMS;
                                    i++;
                                    if (i < argc) {
                                        char const* umsTarget = argv[i];
                                        if (strcmp(umsTarget, "sd") == 0) {
                                            hekate.umsTarget = NXHekateStorageTargetSD;
                                        }
                                        else if (strcmp(umsTarget, "boot0") == 0) {
                                            hekate.umsTarget = NXHekateStorageTargetInternalBOOT0;
                                        }
                                        else if (strcmp(umsTarget, "boot1") == 0) {
                                            hekate.umsTarget = NXHekateStorageTargetInternalBOOT1;
                                        }
                                        else if (strcmp(umsTarget, "gpp") == 0) {
                                            hekate.umsTarget = NXHekateStorageTargetInternalGPP;
                                        }
                                        else if (strcmp(umsTarget, "emu-boot0") == 0) {
                                            hekate.umsTarget = NXHekateStorageTargetEmuBOOT0;
                                        }
                                        else if (strcmp(umsTarget, "emu-boot1") == 0) {
                                            hekate.umsTarget = NXHekateStorageTargetEmuBOOT1;
                                        }
                                        else if (strcmp(umsTarget, "emu-gpp") == 0) {
                                            hekate.umsTarget = NXHekateStorageTargetEmuGPP;
                                        }
                                        else {
                                            fprintf(stderr, ESC_RED "error: unknown Hekate UMS target %s" ESC_LN, umsTarget);
                                            printUsage();
                                            return 1;
                                        }
                                    }
                                    else {
                                        fprintf(stderr, ESC_RED "error: --hekate ums requires an argument" ESC_LN);
                                        printUsage();
                                        return 1;
                                    }
                                }
                                else {
                                    fprintf(stderr, ESC_RED "error: invalid --hekate boot command %s" ESC_LN, cmd);
                                    printUsage();
                                    return 1;
                                }
                                hekateBootConfigured = YES;
                            }
                            else {
                                fprintf(stderr, ESC_RED "error: --hekate requires a command" ESC_LN);
                                printUsage();
                                return 1;
                            }
                        }
                        else if (strcmp(a, "hekate-log") == 0) {
                            hekateExpected = YES;
                            hekate.logFlag = YES;
                        }
                        else {
                            fprintf(stderr, ESC_RED "error: unknown long argument --%s" ESC_LN, a);
                            printUsage();
                            return 1;
                        }
                        longarg = true;
                        break;
                    }
                    default: {
                        fprintf(stderr, ESC_RED "error: unknown argument -%c" ESC_LN, c);
                        printUsage();
                        return 1;
                    }
                }
            }
            else {
                switch (pos) {
                    case 0: {
                        NSString *path = [NSString stringWithUTF8String:argv[i]];
                        NXLog(@"CMD: Using payload %@", path);
                        cmdTool.image = [NSData dataWithContentsOfFile:path];
                        if (cmdTool.image == nil) {
                            fprintf(stderr, ESC_RED "error: failed to load payload" ESC_LN);
                            return 1;
                        }
                        break;
                    }
                    default: {
                        fprintf(stderr, ESC_RED "error: too many positional arguments" ESC_LN);
                        printUsage();
                        return 1;
                    }
                }
                pos++;
            }
        }

        if (!cmdTool.image) {
            fprintf(stderr, ESC_RED "error: a payload path must be set" ESC_LN);
            printUsage();
            return 1;
        }
        
        if (hekateExpected) {
            hekate.payload = cmdTool.image;
            if (!hekate.payloadSupported) {
                fprintf(stderr, ESC_RED "error: Hekate options used on non-Hekate or unsupported payload" ESC_LN);
                return 1;
            }
            NXLog(@"CMD: Using Hekate %@", hekate.version);
            cmdTool.image = [hekate commitToImage];
        }

        if (!cmdTool.relocator) {
            size_t n;
            void *p = getsectiondata(&_mh_execute_header, "__TEXT", "__intermezzo", &n);
            if (!p) {
                fprintf(stderr, ESC_RED "error: getsectiondata failed; your nxboot build is broken" ESC_LN);
                return 1;
            }
            cmdTool.relocator = [NSData dataWithBytesNoCopy:p length:n freeWhenDone:NO];
            NXLog(@"CMD: Using default relocator with size %lu bytes", (unsigned long)n);
        }

        [cmdTool start];
        fprintf(stderr, "waiting for Nintendo Switch in RCM mode...\n");

        dispatch_async(dispatch_get_main_queue(), ^{
            struct sigaction sa = {
                .sa_handler = onSignal,
                .sa_flags   = 0
            };
            sigaction(SIGINT, &sa, 0);
            sigaction(SIGTERM, &sa, 0);
            NXLog(@"CMD: Signal handler installed");
        });

        CFRunLoopRun();

        NXLog(@"CMD: Exiting normally, last boot %@", cmdTool.lastBootFailed ? @"failed" : @"OK");

        return cmdTool.lastBootFailed ? 1 : 0;
    }
}
