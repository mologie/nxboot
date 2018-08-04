/**
 * @file main window view controller
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "MainViewController.h"
#import "AppConfig.h"
#import "AppDelegate.h"
#import "BootProfile+CoreDataClass.h"
#import "CheckboxCellView.h"
#import "NXExec.h"
#import "NXUSBDevice.h"
#import "NXUSBDeviceEnumerator.h"

@import AppCenterAnalytics;

@interface MainViewController () <
    NSTableViewDelegate,
    NSTableViewDataSource,
    NXUSBDeviceEnumeratorDelegate
>
@property (strong) AppConfig *config;
@property (strong) NXUSBDeviceEnumerator *usbEnum;
@property (strong) NXUSBDevice *device;
@property (weak) IBOutlet NSVisualEffectView *backgroundView;
@property (weak) IBOutlet NSTextField *versionLabel;
@property (weak) IBOutlet NSScrollView *tableView;
@property (weak) IBOutlet NSSegmentedControl *tableButtons;
@property (weak) IBOutlet NSButton *bootNowButton;
@property (weak) IBOutlet NSImageView *statusImage;
@property (weak) IBOutlet NSTextField *statusLabel;
@property (strong) NSString *bootNowText;
@property (strong) NSString *statusLabelWaitingText;
@property (assign) BOOL active;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bootProfileDidChange)
                                                 name:AppConfigSelectedBootProfileIDChanged object:nil];

    self.config = [AppConfig sharedConfig];
    [self createDemoProfile];
    [self bootProfileDidChange];

    self.bootNowText = self.bootNowButton.stringValue;
    self.statusLabelWaitingText = self.statusLabel.stringValue;

    self.usbEnum = [[NXUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum addFilterForVendorID:kTegraNintendoSwitchVendorID productID:kTegraNintendoSwitchProductID];
    [self.usbEnum start];

    [self tableViewDidClearSelection];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    self.view.window.movableByWindowBackground = YES;
    self.view.window.appearance = self.backgroundView.appearance;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.usbEnum stop];
}

#pragma mark - Start/Stop States

- (void)bootStart {
    self.bootNowButton.stringValue = @"Active - Click to Stop";
    self.active = YES;
    if (self.device) {
        [self bootExecSelected];
    }
    else {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
        self.statusLabel.stringValue = self.statusLabelWaitingText;
    }
}

- (void)bootExecSelected {
    assert(self.device != nil);

    self.statusImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];
    self.statusLabel.stringValue = @"Device connected! Booting...";

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
        BootProfile *profile = self.bootProfile;
        if (!profile) {
            self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
            self.statusLabel.stringValue = @"Error: No boot profile is selected.";
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Canceled", @"Reason": @"No Boot Profile Selected"}];
            return;
        }
        NSData *relocator = [self relocatorForProfile:profile];
        NSData *bootImage = [self bootImageForProfile:profile];
        if (!relocator || !bootImage) {
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Canceled", @"Reason": @"Boot Profile Invalid"}];
            return;
        }
        if (NXExec(self.device->_intf, relocator, bootImage, &error)) {
            self.statusImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];
            self.statusLabel.stringValue = @"Success! 🎉";
            [MSAnalytics trackEvent:@"SwitchBootEnd" withProperties:@{@"Status": @"Success"}];
            [MSAnalytics trackEvent:@"SwitchBootSuccess"];
        }
        else {
            self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: %@", error];
        }
    });
}

- (void)bootStop {
    if (self.device) {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];
        self.statusLabel.stringValue = @"Device connected. Click the Boot Now button to start.";
    }
    else {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
        self.statusLabel.stringValue = self.statusLabelWaitingText;
    }
    self.bootNowButton.stringValue = self.bootNowText;
    self.active = NO;
}

#pragma mark - Core Data

- (NSManagedObjectContext *)managedObjectContext {
    AppDelegate *delegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
    return delegate.persistentContainer.viewContext;
}

- (void)createDemoProfile {
    NSFetchRequest *fetchRequest = [BootProfile fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isDemoProfile = 1"];
    NSError *error = nil;
    NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    if (fetchedObjects.count == 0) {
        // on first run, create a demo profile with the Fusée Demo payload and make it the active profile
        BootProfile *demoProfile = [[BootProfile alloc] initWithContext:self.managedObjectContext];
        demoProfile.name = @"Fusée Demo";
        demoProfile.relocatorName = @"intermezzo.bin";
        demoProfile.payloadName = @"fusee.bin";
        demoProfile.isDemoProfile = YES;
        if (![self.managedObjectContext save:&error]) {
            /*
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn't Initialize Database"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Quit" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                exit(1);
            }]];
            [self presentViewController:alert animated:YES completion:nil];
            */
            return;
        }
        self.config.selectedBootProfileID = demoProfile.objectID.URIRepresentation.absoluteString;
    }
    else if (!self.config.selectedBootProfileID) {
        // the configuration file may have been deleted by the user. store the demo profile ID again.
        BootProfile *demoProfile = fetchedObjects.firstObject;
        self.config.selectedBootProfileID = demoProfile.objectID.URIRepresentation.absoluteString;
    }
}

- (void)bootProfileDidChange {
    // BootProfile *profile = self.bootProfile;
    // TODO
}

- (BootProfile *)bootProfile {
    NSURL *url = [NSURL URLWithString:self.config.selectedBootProfileID];
    NSManagedObjectID *objID = [self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
    return [self.managedObjectContext existingObjectWithID:objID error:nil];
}

- (NSData *)relocatorForProfile:(BootProfile *)profile {
    if (profile.relocatorBin.length > 0) {
        return profile.relocatorBin;
    }
    NSURL *url = [[NSBundle mainBundle] URLForResource:profile.relocatorName withExtension:nil subdirectory:@"Payloads"];
    if (!url) {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: Could not locate relocator with name %@", profile.relocatorName];
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:nil];
    if (!data) {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: Could not load relocator with name %@", profile.relocatorName];
        return nil;
    }
    return data;
}

- (NSData *)bootImageForProfile:(BootProfile *)profile {
    if (profile.payloadBin.length > 0) {
        return profile.payloadBin;
    }
    NSURL *url = [[NSBundle mainBundle] URLForResource:profile.payloadName withExtension:nil subdirectory:@"Payloads"];
    if (!url) {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: Could not locate payload with name %@", profile.payloadName];
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:nil];
    if (!data) {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"Error: Could not load payload with name %@", profile.payloadName];
    }
    return data;
}

#pragma mark - Actions

- (IBAction)tableButtonClicked:(id)sender {
}

- (IBAction)bootNowClicked:(id)sender {
}

#pragma mark - Table View

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
}

- (void)tableViewDidClearSelection {
    [self.tableButtons setEnabled:NO forSegment:1]; // disable remove button
    [self.tableButtons setEnabled:NO forSegment:2]; // disable edit button
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return 1;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableColumn == tableView.tableColumns[0]) {
        CheckboxCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.checkbox.state = NSControlStateValueOff;
        return cell;
    }
    else if (tableColumn == tableView.tableColumns[1]) {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.textField.stringValue = @"Fusée Demo";
        return cell;
    }
    else if (tableColumn == tableView.tableColumns[2]) {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.textField.stringValue = @"intermezzio";
        return cell;
    }
    else if (tableColumn == tableView.tableColumns[3]) {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.textField.stringValue = @"fusee.bin";
        return cell;
    }
    else {
        return nil;
    }
}

#pragma mark - NXUSBDeviceEnumeratorDelegate

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceConnected:(NXUSBDevice *)device {
    assert(device != nil);
    self.device = device;
    if (self.active) {
        [self bootExecSelected];
    }
    else {
        self.statusImage.image = [NSImage imageNamed:NSImageNameStatusAvailable];
        self.statusLabel.stringValue = @"Device connected. Click the Boot Now button to start.";
    }
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(NXUSBDevice *)device {
    self.device = nil;
    self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
    self.statusLabel.stringValue = self.active ? @"Device disconnected. Waiting for next connection..." : self.statusLabelWaitingText;
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {
    self.statusImage.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Connection error: %@", err];
}

@end
