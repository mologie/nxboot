/**
 * @file app delegate
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (readonly, strong) NSPersistentContainer *persistentContainer;
@end
