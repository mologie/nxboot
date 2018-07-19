/**
 * @file application delegate
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "AppDelegate.h"

#ifndef NXBOOT_LEGACY
@import AppCenter;
@import AppCenterAnalytics;
@import AppCenterCrashes;
#endif

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifndef NXBOOT_LEGACY
    [MSAppCenter start:@"0665136b-48d8-4d13-98f9-1d21a3dbcd59" withServices:@[[MSAnalytics class], [MSCrashes class]]];
#endif
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {}

- (void)applicationDidEnterBackground:(UIApplication *)application {}

- (void)applicationWillEnterForeground:(UIApplication *)application {}

- (void)applicationDidBecomeActive:(UIApplication *)application {}

- (void)applicationWillTerminate:(UIApplication *)application {}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    // copy the file at 'url' to the documents directory
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *name = url.lastPathComponent;
    NSURL *documentsDir = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *inboxDir = [[documentsDir URLByAppendingPathComponent:@"Inbox" isDirectory:YES] URLByResolvingSymlinksInPath];
    NSURL *inParentDir = [[url URLByDeletingLastPathComponent] URLByResolvingSymlinksInPath];
    NSURL *targetFilePath = [documentsDir URLByAppendingPathComponent:name];
    NSError *error = nil;
    BOOL importOK = NO;
    [fm removeItemAtURL:targetFilePath error:nil];
    if ([inParentDir.absoluteString isEqualToString:inboxDir.absoluteString]) {
        importOK = [fm moveItemAtURL:url toURL:targetFilePath error:&error]; // move file out of Inbox directory
    }
    else {
        importOK = [fm copyItemAtURL:url toURL:targetFilePath error:&error];
    }
    if (importOK) {
        NSString *message = [NSString stringWithFormat:@"The file %@ has been imported and is available in the boot profiles editor.", name];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"File Imported"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        return YES;
    }
    else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Failed"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        return NO;
    }
}

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
        if (error) {
            // Typical reasons for an error here include:
            // * The parent directory does not exist, cannot be created, or disallows writing.
            // * The persistent store is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The store could not be migrated to the current model version.
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn't Create Database"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Quit" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                exit(1);
            }]];
            [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    }];
}

@end
