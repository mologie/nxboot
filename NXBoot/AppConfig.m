/**
 * @file application global settings
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "AppConfig.h"

NSNotificationName const FLConfigSelectedBootProfileIDChanged = @"FLConfigSelectedBootProfileIDChanged";

static NSString *const kFLConfigSelectedBootProfile = @"FLSelectedBootProfile";

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
    return [self.store stringForKey:kFLConfigSelectedBootProfile];
}

- (void)setSelectedBootProfileID:(NSString *)selectedBootProfileID {
    [self.store setObject:selectedBootProfileID forKey:kFLConfigSelectedBootProfile];
    [self.notificationCenter postNotificationName:FLConfigSelectedBootProfileIDChanged object:self];
}

@end
