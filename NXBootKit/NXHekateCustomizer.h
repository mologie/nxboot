#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NXHekateBootTarget) {
    NXHekateBootTargetMenu,
    NXHekateBootTargetID,
    NXHekateBootTargetIndex,
    NXHekateBootTargetUMS
};

typedef NS_ENUM(NSInteger, NXHekateStorageTarget) {
    NXHekateStorageTargetSD,
    NXHekateStorageTargetInternalBOOT0,
    NXHekateStorageTargetInternalBOOT1,
    NXHekateStorageTargetInternalGPP,
    NXHekateStorageTargetEmuBOOT0,
    NXHekateStorageTargetEmuBOOT1,
    NXHekateStorageTargetEmuGPP
};

@interface NXHekateCustomizer : NSObject

- (instancetype)initWithPayload:(NSData *)payload;
- (NSData *)commitToImage;

@property (nonatomic, strong) NSData *payload;
@property (readonly, getter=isPayloadSupported) BOOL payloadSupported;
@property (readonly) NSString *version;
@property (nonatomic, assign) NXHekateBootTarget bootTarget;
@property (nonatomic, assign) NSInteger bootIndex;
@property (nonatomic, strong) NSString *bootID;
@property (nonatomic, assign) NXHekateStorageTarget umsTarget;
@property (nonatomic, assign) BOOL logFlag;

@end

NS_ASSUME_NONNULL_END
