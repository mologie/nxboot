#import <Foundation/Foundation.h>

#if __LP64__
#define HAVE_SENTRY 1
#endif

NS_ASSUME_NONNULL_BEGIN

@interface Settings : NSObject

#ifdef HAVE_SENTRY
@property (nonatomic, class, assign) BOOL allowCrashReports;
@property (nonatomic, class, assign) BOOL allowUsagePings;
+ (void)applySentryOptions;
#endif

@end

NS_ASSUME_NONNULL_END
