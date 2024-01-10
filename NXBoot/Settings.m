#import "Settings.h"
#import "PayloadStorage.h"

@import AppCenterAnalytics;
@import AppCenterCrashes;

@implementation Settings

+ (BOOL)allowCrashReports {
    return [MSACCrashes isEnabled];
}

+ (void)setAllowCrashReports:(BOOL)enableCrashReports {
    [MSACCrashes setEnabled:enableCrashReports];
}

+ (BOOL)allowUsagePings {
    return [MSACAnalytics isEnabled];
}

+ (void)setAllowUsagePings:(BOOL)enableUsagePings {
    [MSACAnalytics setEnabled:enableUsagePings];
}

@end
