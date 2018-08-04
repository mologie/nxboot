/**
 * @file application global settings
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "AppConfig.h"
#import "AppConfig+Private.h"

NSNotificationName const AppConfigSelectedBootProfileIDChanged = @"NXBootAppConfigSelectedBootProfileIDChanged";
static NSString *const kAppConfigSelectedBootProfile = @"NXBootAppConfigSelectedBootProfile";

@interface AppConfig ()
@property (strong, nonatomic) NSUserDefaults *store;
@property (strong, nonatomic) NSNotificationCenter *notificationCenter;
@end

@implementation AppConfig

+ (instancetype)sharedConfig {
    static AppConfig *instance = nil;
    if (!instance) {
        dispatch_once_t once = 0;
        dispatch_once(&once, ^{
            instance = [[AppConfig alloc] init];
        });
    }
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.store = [NSUserDefaults standardUserDefaults];
        self.notificationCenter = [NSNotificationCenter defaultCenter];
    }
    return self;
}

- (NSString *)selectedBootProfileID {
    return [self.store stringForKey:kAppConfigSelectedBootProfile];
}

- (void)setSelectedBootProfileID:(NSString *)selectedBootProfileID {
    [self.store setObject:selectedBootProfileID forKey:kAppConfigSelectedBootProfile];
    [self.notificationCenter postNotificationName:AppConfigSelectedBootProfileIDChanged object:self];
}

@end
