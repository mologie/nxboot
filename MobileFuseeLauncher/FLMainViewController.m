/**
 * @file coordinates GUI and exploit implementation
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "FLMainViewController.h"
#import "FLBootProfile+CoreDataClass.h"
#import "FLConfig.h"
#import "FLExec.h"
#import "FLUSBDeviceEnumerator.h"
#import "AppDelegate.h"

@import AppCenterAnalytics;

@interface FLMainViewController () <FLUSBDeviceEnumeratorDelegate>
@property (nonatomic, strong) FLConfig *config;
@property (strong, nonatomic) FLUSBDeviceEnumerator *usbEnum;
@property (strong, nonatomic) FLUSBDevice *device;
@property (weak, nonatomic) IBOutlet UILabel *profileNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *profileDetailLabel;
@property (strong, nonatomic) NSString *bootStatus;
@property (strong, nonatomic) NSString *bootNowText;
@property (weak, nonatomic) IBOutlet UILabel *bootButtonLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *bootActivityIndicator;
@property (assign, nonatomic) BOOL active;
@end

@implementation FLMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bootProfileDidChange)
                                                 name:FLConfigSelectedBootProfileIDChanged object:nil];

    self.view.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];

    self.config = [FLConfig sharedConfig];
    [self createDemoProfile];
    [self bootProfileDidChange];

    self.bootNowText = self.bootButtonLabel.text;
    [self setIdleBootStatus];

    self.usbEnum = [[FLUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum addFilterForVendorID:kTegraNintendoSwitchVendorID productID:kTegraNintendoSwitchProductID];
    [self.usbEnum start];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.usbEnum stop];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    // eek: this is triggered by the 'device not compatible' notifications, too
    // [self bootStop];
}

#pragma mark - Properties

- (void)setBootStatus:(NSString *)bootStatus {
    _bootStatus = bootStatus;
    [UIView setAnimationsEnabled:NO];
    [self.tableView beginUpdates];
    [self setTableSection:2 footerText:bootStatus];
    [self.tableView endUpdates];
    [UIView setAnimationsEnabled:YES];
}

- (void)setIdleBootStatus {
    if (self.device) {
        self.bootStatus = @"Device connected! Tap the Boot Now button to start.";
    }
    else {
        self.bootStatus = @"No Nintendo Switch in RCM mode was connected yet. "
            "Connect a device using a Lightning OTG adapter and tap the above button.";
    }
}

#pragma mark - Table

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2 && indexPath.row == 0) {
        if (!self.active) {
            [self bootStart];
        }
        else {
            [self bootStop];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) {
        return self.bootStatus;
    }
    return [super tableView:tableView titleForFooterInSection:section];
}

- (void)setTableSection:(NSInteger)section footerText:(NSString *)text {
    UITableViewHeaderFooterView *sectionFooterView = [self.tableView footerViewForSection:section];
    UILabel *label = sectionFooterView.textLabel;
    label.text = text;
    label.numberOfLines = 0;
    CGSize newSize = [label sizeThatFits:label.frame.size];
    CGRect newFrame = label.frame;
    newFrame.size.height = newSize.height;
    newFrame.size.width = self.tableView.frame.size.width - newFrame.origin.x * 2;
    label.frame = newFrame;
}

#pragma mark - Tegra Device Interaction

- (void)bootStart {
    [self.bootActivityIndicator startAnimating];
    self.bootButtonLabel.text = @"Active - Tap to Stop";
    self.active = YES;

    if (self.device) {
        [self bootExecSelected];
    }
    else {
        self.bootStatus = @"Waiting for Nintendo Switch in RCM mode...";
    }
}

- (void)bootExecSelected {
    assert(self.device != nil);
    self.bootStatus = @"Device connected! Booting...";

    // analytics: log start event for timing
    // the end event and result will also be logged.
    [MSAnalytics trackEvent:@"SwitchBootStart"];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *error = nil;
        if (!self.device) {
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Canceled", @"Reason": @"Device Disappeared"}];
            return;
        }
        if (!self.active) {
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Canceled", @"Reason": @"User Canceled"}];
            return;
        }
        FLBootProfile *profile = self.bootProfile;
        if (!profile) {
            self.bootStatus = @"Error: No boot profile is selected.";
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Canceled", @"Reason": @"No Boot Profile Selected"}];
            return;
        }
        NSData *relocator = [self relocatorForProfile:profile];
        NSData *bootImage = [self bootImageForProfile:profile];
        if (!relocator || !bootImage) {
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Canceled", @"Reason": @"Boot Profile Invalid"}];
            return;
        }
        if (FLExec(self.device->_intf, relocator, bootImage, &error)) {
            self.bootStatus = @"Success! 🎉";

            // analytics: log success events
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Success"}];
            [MSAnalytics trackEvent:@"SwitchBootSuccess"];
        }
        else {
            self.bootStatus = [NSString stringWithFormat:@"Error: %@", error];

            // analytics: log error events and error messages (these contain technical info only)
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Error", @"Messaage": error}];
            [MSAnalytics trackEvent:@"SwitchBootFailure" withProperties:@{@"Messaage": error}];
        }
    });
}

- (void)bootStop {
    [self.bootActivityIndicator stopAnimating];
    [self setIdleBootStatus];
    self.bootButtonLabel.text = self.bootNowText;
    self.active = NO;
}

#pragma mark - Core Data

- (NSManagedObjectContext *)managedObjectContext {
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    return delegate.persistentContainer.viewContext;
}

- (void)createDemoProfile {
    NSFetchRequest *fetchRequest = [FLBootProfile fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isDemoProfile = 1"];
    NSError *error = nil;
    NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    if (fetchedObjects.count == 0) {
        // on first run, create a demo profile with the Fusée Demo payload and make it the active profile
        FLBootProfile *demoProfile = [[FLBootProfile alloc] initWithContext:self.managedObjectContext];
        demoProfile.name = @"Fusée Demo";
        demoProfile.relocatorName = @"intermezzo.bin";
        demoProfile.payloadName = @"fusee.bin";
        demoProfile.isDemoProfile = YES;
        if (![self.managedObjectContext save:&error]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn't Initialize Database"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Quit" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                exit(1);
            }]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        self.config.selectedBootProfileID = demoProfile.objectID.URIRepresentation.absoluteString;
    }
    else if (!self.config.selectedBootProfileID) {
        // the configuration file may have been deleted by the user. store the demo profile ID again.
        FLBootProfile *demoProfile = fetchedObjects.firstObject;
        self.config.selectedBootProfileID = demoProfile.objectID.URIRepresentation.absoluteString;
    }
}

- (void)bootProfileDidChange {
    FLBootProfile *profile = self.bootProfile;
    self.profileNameLabel.text = profile.name;
    self.profileDetailLabel.text = [NSString stringWithFormat:@"%@ loaded via %@", profile.payloadName, profile.relocatorName];
}

- (FLBootProfile *)bootProfile {
    NSURL *url = [NSURL URLWithString:self.config.selectedBootProfileID];
    NSManagedObjectID *objID = [self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
    return [self.managedObjectContext existingObjectWithID:objID error:nil];
}

- (NSData *)relocatorForProfile:(FLBootProfile *)profile {
    if (profile.relocatorBin.length > 0) {
        return profile.relocatorBin;
    }
    NSURL *url = [[NSBundle mainBundle] URLForResource:profile.relocatorName withExtension:nil subdirectory:@"Payloads"];
    if (!url) {
        self.bootStatus = [NSString stringWithFormat:@"Error: Could not locate relocator with name %@", profile.relocatorName];
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:nil];
    if (!data) {
        self.bootStatus = [NSString stringWithFormat:@"Error: Could not load relocator with name %@", profile.relocatorName];
        return nil;
    }
    return data;
}

- (NSData *)bootImageForProfile:(FLBootProfile *)profile {
    if (profile.payloadBin.length > 0) {
        return profile.payloadBin;
    }
    NSURL *url = [[NSBundle mainBundle] URLForResource:profile.payloadName withExtension:nil subdirectory:@"Payloads"];
    if (!url) {
        self.bootStatus = [NSString stringWithFormat:@"Error: Could not locate payload with name %@", profile.payloadName];
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:nil];
    if (!data) {
        self.bootStatus = [NSString stringWithFormat:@"Error: Could not load payload with name %@", profile.payloadName];
    }
    return data;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    [self bootStop];

    // analytics: log navigation events from the main screen
    [MSAnalytics trackEvent:@"Navigation" withProperties:@{@"ID": [NSString stringWithFormat:@"Main-%@", segue.identifier]}];
}

#pragma mark - FLUSBDeviceEnumeratorDelegate

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceConnected:(FLUSBDevice *)device {
    self.device = device;
    if (self.active) {
        [self bootExecSelected];
    }
    else {
        [self setIdleBootStatus];
    }
}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(FLUSBDevice *)device {
    self.device = nil;
    if (self.active) {
        self.bootStatus = @"Device disconnected. Waiting for next connection...";
    }
    else {
        [self setIdleBootStatus];
    }
}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {
    self.bootStatus = [NSString stringWithFormat:@"Connection error: %@", err];
}

@end
