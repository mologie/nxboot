/**
 * @file exploits a Tegra X1 CPU's bootloader using Fusée Gelée
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import "FLUSBDevice.h"

@class FLExec;

@protocol FLExecDelegate

@end

@interface FLExec : NSObject
@property (weak, nonatomic) id<FLExecDelegate> delegate;
@property (strong, nonatomic) FLUSBDevice *device;
@property (strong, nonatomic) NSData *relocator;
@property (strong, nonatomic) NSData *bootImage;
- (void)boot;
- (void)cancel;
@end
