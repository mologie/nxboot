/**
 * @file application delegate
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "AppDelegate.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {}

- (void)applicationDidEnterBackground:(UIApplication *)application {}

- (void)applicationWillEnterForeground:(UIApplication *)application {}

- (void)applicationDidBecomeActive:(UIApplication *)application {}

- (void)applicationWillTerminate:(UIApplication *)application {}


#pragma mark - Core Data Stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
    if (_persistentContainer == nil) {
        @synchronized (self) {
            if (_persistentContainer == nil) {
                [self createPersistentContainer];
            }
        }
    }

    return _persistentContainer;
}

- (void)createPersistentContainer {
    _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"Model"];
    [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
        if (error != nil) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate.
            // You should not use this function in a shipping application, although it may be useful during development.
            /*
             Typical reasons for an error here include:
             * The parent directory does not exist, cannot be created, or disallows writing.
             * The persistent store is not accessible, due to permissions or data protection when the device is locked.
             * The device is out of space.
             * The store could not be migrated to the current model version.
             Check the error message to determine what the actual problem was.
             */
            NSLog(@"ERR: createPersistentContainer: %@, %@", error, error.userInfo);
            abort();
        }
    }];
}

#pragma mark - Core Data Saving Support

- (void)saveContext {
    NSManagedObjectContext *context = self.persistentContainer.viewContext;
    NSError *error = nil;
    if (context.hasChanges && ![context save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate.
        // You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"ERR: Core Data: %@, %@", error, error.userInfo);
        abort();
    }
}

@end
