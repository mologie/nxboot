/**
 * @file listens for USB device connections matching a PID and VID
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import "NXUSBDevice.h"

@class NXUSBDeviceEnumerator;

@protocol FLUSBDeviceEnumeratorDelegate
- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceConnected:(NXUSBDevice *)device;
- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(NXUSBDevice *)device;
- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err;
@end

@interface NXUSBDeviceEnumerator : NSObject
@property (weak, nonatomic) id<FLUSBDeviceEnumeratorDelegate> delegate;
- (void)addFilterForVendorID:(UInt16)vendorID productID:(UInt16)productID;
- (void)start;
- (void)stop;
@end
