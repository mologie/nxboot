#import <Foundation/Foundation.h>
#import <NXBootKit/NXUSBDevice.h>
#import <NXBootKit/NXVisibility.h>

NS_ASSUME_NONNULL_BEGIN

@class NXUSBDeviceEnumerator;

@protocol NXUSBDeviceEnumeratorDelegate
- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceConnected:(NXUSBDevice *)device;
- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(NXUSBDevice *)device;
- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err;
@end

NXBOOTKIT_PUBLIC
@interface NXUSBDeviceEnumerator : NSObject
@property (weak, nonatomic) id<NXUSBDeviceEnumeratorDelegate> delegate;
- (void)setFilterForVendorID:(UInt16)vendorID productID:(UInt16)productID;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
