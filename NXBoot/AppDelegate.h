/**
 * @file application delegate
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (readonly, strong) NSPersistentContainer *persistentContainer;
@end
