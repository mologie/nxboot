/**
 * @file listens for USB device connections matching a PID and VID
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>
#import "FLUSBDevice.h"

@class FLUSBDeviceEnumerator;

@protocol FLUSBDeviceEnumeratorDelegate
- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceConnected:(FLUSBDevice *)device;
- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(FLUSBDevice *)device;
- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err;
@end

@interface FLUSBDeviceEnumerator : NSObject
@property (weak, nonatomic) id<FLUSBDeviceEnumeratorDelegate> delegate;
- (void)addFilterForVendorID:(UInt16)vendorID productID:(UInt16)productID;
- (void)start;
- (void)stop;
@end
