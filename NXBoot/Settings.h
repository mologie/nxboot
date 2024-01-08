#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Settings : NSObject

@property (nonatomic, class, assign) BOOL allowCrashReports;
@property (nonatomic, class, assign) BOOL allowUsagePings;

+ (void)applySentryOptions;

@end

NS_ASSUME_NONNULL_END
