#import <Foundation/Foundation.h>
#import <NXBootKit/NXExec.h>

NS_ASSUME_NONNULL_BEGIN

@class NXUSBDeviceEnumerator;

@interface NXUSBDevice : NSObject {
@public
    NXUSBDeviceInterface **_intf;
    UInt32 _locationID;
    io_object_t _notification;
}
@property (weak, nonatomic) NXUSBDeviceEnumerator *parentEnum;
@property (strong, nonatomic) NSString *name;
- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
