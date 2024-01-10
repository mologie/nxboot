#import "AppDelegate.h"
#import "PayloadStorage.h"
#import "Settings.h"

@import AppCenter;
@import AppCenterAnalytics;
@import AppCenterCrashes;

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [MSACAppCenter start:@"0665136b-48d8-4d13-98f9-1d21a3dbcd59" withServices:@[MSACAnalytics.class, MSACCrashes.class]];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {}

- (void)applicationDidEnterBackground:(UIApplication *)application {}

- (void)applicationWillEnterForeground:(UIApplication *)application {}

- (void)applicationDidBecomeActive:(UIApplication *)application {}

- (void)applicationWillTerminate:(UIApplication *)application {}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSURL *documentsDir = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *inboxDir = [documentsDir URLByAppendingPathComponent:@"Inbox" isDirectory:YES].URLByResolvingSymlinksInPath;
    BOOL isInInbox = [url.URLByDeletingLastPathComponent.URLByResolvingSymlinksInPath isEqual:inboxDir];
    NSError *error = nil;
    if ([[PayloadStorage sharedPayloadStorage] importPayload:url.path move:isInInbox error:&error]) {
        NSString *message = [NSString stringWithFormat:@"Your payload %@ is now available in the payloads list.", url.lastPathComponent];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Successful"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self.window.rootViewController presentViewController:alert animated:YES completion:^{
            // TODO: would be nicer to have the model notify the table controller about the new item,
            //  and let the table controller add the item normally in response.
            [[NSNotificationCenter defaultCenter] postNotificationName:NXBootPayloadStorageChangedExternally object:self];
        }];
        return YES;
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Failed"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        return NO;
    }
}

@end
