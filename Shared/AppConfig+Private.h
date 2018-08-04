/**
 * @file application global settings
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

@interface AppConfig (Private)
@property (strong, nonatomic, readonly) NSUserDefaults *store;
@property (strong, nonatomic, readonly) NSNotificationCenter *notificationCenter;
@end
