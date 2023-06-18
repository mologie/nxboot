#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const NXBootPayloadStorageChangedExternally;

@interface Payload : NSObject

@property (nonatomic, strong) NSString *path;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) unsigned long long fileSize;
@property (nonatomic, readonly) NSDate *fileDate;

@end

@interface PayloadStorage : NSObject

+ (instancetype)sharedPayloadStorage;
+ (NSData *)relocator;

- (NSArray<Payload *> *)loadPayloads;
- (void)storePayloadSortOrder:(NSArray<Payload *> *)payloads;
- (Payload *)importPayload:(NSString *)filePath move:(BOOL)moveFile error:(NSError **)error;
- (BOOL)renamePayload:(nonnull Payload *)payload withNewName:(nonnull NSString *)name error:(NSError **)error;
- (BOOL)deletePayload:(nonnull Payload *)payload error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
