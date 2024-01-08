#import "Settings.h"
#import "PayloadStorage.h"

@import Sentry;

static NSString *const NXBootSettingsKeyAllowUsageCrashReports = @"NXBootAllowCrashReports";
static NSString *const NXBootSettingsKeyAllowUsagePings = @"NXBootAllowUsagePings";

@implementation Settings

+ (BOOL)_getBool:(NSString *)key defaultValue:(BOOL)defaultValue {
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return value ? [value boolValue] : defaultValue;
}

+ (void)_setBool:(NSString *)key value:(BOOL)value {
    [[NSUserDefaults standardUserDefaults] setObject:@(value) forKey:key];
}

+ (BOOL)allowCrashReports {
    return [self _getBool:NXBootSettingsKeyAllowUsageCrashReports defaultValue:YES];
}

+ (void)setAllowCrashReports:(BOOL)enableCrashReports {
    [self _setBool:NXBootSettingsKeyAllowUsageCrashReports value:enableCrashReports];
    [self applySentryOptions];
}

+ (BOOL)allowUsagePings {
    return [self _getBool:NXBootSettingsKeyAllowUsagePings defaultValue:YES];
}

+ (void)setAllowUsagePings:(BOOL)enableUsagePings {
    [self _setBool:NXBootSettingsKeyAllowUsagePings value:enableUsagePings];
    [self applySentryOptions];
}

+ (void)applySentryOptions {
    // Sentry is only supported on iOS 11 and later, but built by default for iOS 12 and later.
    // Won't touch it on older platforms to avoid crashes.
    static bool initialized = false;
    if (@available(iOS 12, *)) {
        if (initialized) {
            [SentrySDK close];
            initialized = false;
        }
        if (!Settings.allowCrashReports && !Settings.allowUsagePings) {
            return;
        }
        [SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
            options.dsn = @"https://6f191f8afd06257e9b2c2cdd7977cd1e@o4506496566231040.ingest.sentry.io/4506496570032128";
            options.enableAppHangTracking = false;
            options.enableAutoSessionTracking = Settings.allowUsagePings;
            options.enableCrashHandler = Settings.allowCrashReports;
            options.enableWatchdogTerminationTracking = false;
#ifdef DEBUG
            options.debug = true;
#endif
        }];
        initialized = true;
    }
}

@end
