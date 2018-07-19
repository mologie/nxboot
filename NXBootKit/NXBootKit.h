/**
 * @file NXBootKit globals
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de
 */

#import <CoreFoundation/CoreFoundation.h>

extern BOOL NXBootKitDebugEnabled;

#define NXLog(...) do { if (NXBootKitDebugEnabled) NSLog(__VA_ARGS__); } while (0)
