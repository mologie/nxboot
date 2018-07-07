/**
 * @file exploits a Tegra X1 CPU's bootloader using Fusée Gelée
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import "FLUSBDevice.h"

BOOL FLExec(FLUSBDevice *device, NSData *relocator, NSData *image, NSString **err);
