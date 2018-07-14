/**
 * @file application global settings
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>

extern NSNotificationName const FLConfigSelectedBootProfileIDChanged;

@interface AppConfig : NSObject
@property (nonatomic) NSString *selectedBootProfileID;
+ (instancetype)sharedConfig;
@end
