/**
 * @file app delegate
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {}

- (void)applicationWillTerminate:(NSNotification *)aNotification {}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
