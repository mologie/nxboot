#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Settings : NSObject

@property (nonatomic, class, assign) BOOL enableCrashReports;
@property (nonatomic, class, assign) BOOL enableUsagePings;

+ (void)applySentryOptions;

@end

NS_ASSUME_NONNULL_END
