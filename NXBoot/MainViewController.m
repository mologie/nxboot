#import "MainViewController.h"
#import "AppDelegate.h"
#import "FLBootProfile+CoreDataClass.h"
#import "NXExec.h"
#import "NXUSBDeviceEnumerator.h"
#import "PayloadStorage.h"
#import "Settings.h"

@import Sentry;

@interface MainViewController () <
        NXUSBDeviceEnumeratorDelegate,
        UIDocumentPickerDelegate>

@property (nonatomic, strong) UIColor *textColorButton;
@property (nonatomic, strong) UIColor *textColorInactive;
@property (nonatomic, strong) NSDateFormatter *payloadDateFormatter;
@property (nonatomic, strong) PayloadStorage *payloadStorage;
@property (nonatomic, strong) NSMutableArray<Payload *> *payloads;

@property (nonatomic, strong, nullable) Payload *selectedPayload;
@property (nonatomic, strong) NXUSBDeviceEnumerator *usbEnum;
@property (nonatomic, strong, nullable) NXUSBDevice *usbDevice;
@property (nonatomic, strong, nullable) NSString *usbStatus;
@property (nonatomic, strong, nullable) NSString *usbError;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshPayloadList)
                                                 name:NXBootPayloadStorageChangedExternally
                                               object:nil];

    self.textColorButton = [UIColor colorWithRed:0.001 green:0.732 blue:0.883 alpha:1.0];
    if (@available(iOS 13, *)) {
        self.textColorInactive = [UIColor secondaryLabelColor];
    } else {
        self.textColorInactive = [UIColor colorWithRed:0.235 green:0.235 blue:0.263 alpha:0.6];
    }

    self.payloadDateFormatter = [[NSDateFormatter alloc] init];
    self.payloadDateFormatter.dateStyle = NSDateFormatterMediumStyle;
    self.payloadDateFormatter.timeStyle = NSDateFormatterNoStyle;

    self.payloadStorage = [PayloadStorage sharedPayloadStorage];
    self.payloads = [[self.payloadStorage loadPayloads] mutableCopy];

    self.usbEnum = [[NXUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum setFilterForVendorID:kTegraX1VendorID productID:kTegraX1ProductID];
    [self.usbEnum start];

    self.navigationItem.leftBarButtonItem = self.settingsButtonItem;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.usbEnum stop];
}

- (void)bootPayload:(Payload *)payload {
    NSData *relocator = [PayloadStorage relocator];
    assert(relocator != nil);

    NSData *payloadData = payload.data;
    if (!payloadData) {
        self.usbError = @"Failed to load payload data from disk. Please check file permissions.";
        [self updateDeviceStatus:@"Error loading payload"];
        return;
    }

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];

    assert(self.usbDevice != nil);
    NSString *error = nil;
    if (NXExec(self.usbDevice, relocator, payloadData, &error)) {
        self.usbError = nil;
        [self updateDeviceStatus:@"Payload injected 🎉"];
        event.message = [[SentryMessage alloc] initWithFormatted:@"Boot successful"];
    } else {
        self.usbError = error;
        [self updateDeviceStatus:@"Payload injection error"];
        event.message = [[SentryMessage alloc] initWithFormatted:[NSString stringWithFormat:@"Boot failed: %@", error]];
    }

    if (Settings.allowUsagePings) {
        [SentrySDK captureEvent:event];
    }
}

#pragma mark - Table

typedef NS_ENUM(NSInteger, TableSection) {
    TableSectionLinks,
    TableSectionDevice,
    TableSectionPayloads,
};

- (void)refreshPayloadList {
    [self.tableView beginUpdates];
    [self.refreshControl endRefreshing];
    [self setEditing:NO animated:YES];
    self.payloads = [[self.payloadStorage loadPayloads] mutableCopy];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:TableSectionPayloads]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
}

- (IBAction)refreshPayloadList:(id)sender {
    [self refreshPayloadList];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    BOOL wasEditing = self.isEditing;
    UITableViewRowAnimation animation = animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone;

    [self.tableView beginUpdates];

    if (editing && !wasEditing && self.selectedPayload) {
        [self cellForPayload:self.selectedPayload].accessoryType = UITableViewCellAccessoryNone;
        self.selectedPayload = nil;
    }

    [super setEditing:editing animated:animated];

    NSInteger nlinks = [self tableView:self.tableView numberOfRowsInSection:TableSectionLinks];
    for (NSInteger row = 0; row < nlinks; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:TableSectionLinks];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self configureLinkCell:cell];
    }

    NSIndexPath *newPayloadPath = [NSIndexPath indexPathForRow:self.payloads.count inSection:TableSectionPayloads];
    if (self.payloads.count != 0) {
        // will always show "add payload" row when there is no payload
        if (editing && !wasEditing) {
            // add new payload row
            [self.tableView insertRowsAtIndexPaths:@[newPayloadPath] withRowAnimation:animation];
        } else if (!editing && wasEditing) {
            // remove new payload row
            [self.tableView deleteRowsAtIndexPaths:@[newPayloadPath] withRowAnimation:animation];
        }
    }

    // update payload section footer for rename hint
    [self.tableView footerViewForSection:TableSectionPayloads].textLabel.text = [self tableView:self.tableView titleForFooterInSection:TableSectionPayloads];

    [self.tableView endUpdates];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case TableSectionLinks: return 2;
        case TableSectionDevice: return 1;
        case TableSectionPayloads: {
            if (self.payloads.count == 0) {
                return 1;
            } else if (self.isEditing) {
                return self.payloads.count + 1;
            } else {
                return self.payloads.count;
            }
        }
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case TableSectionDevice: return @"Device";
        case TableSectionPayloads: return @"Payloads";
    }
    return [super tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case TableSectionDevice:
            return [self footerForDeviceCell];
        case TableSectionPayloads:
            if (self.isEditing) {
                return @"Tap a payload to change its name.";
            } else {
                return @"Activate a payload to boot it automatically. Use the Edit button to organize your payloads.";
            }
    }
    return [super tableView:tableView titleForFooterInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case TableSectionLinks: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ButtonCell" forIndexPath:indexPath];
            [self configureLinkCell:cell];
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Getting Started";
                    break;
                case 1:
                    cell.textLabel.text = @"About";
                    break;
            }
            return cell;
        }
        case TableSectionDevice: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DeviceCell" forIndexPath:indexPath];
            [self configureDeviceCell:cell];
            return cell;
        }
        case TableSectionPayloads: {
            if (indexPath.row == self.payloads.count) {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ButtonCell" forIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.textLabel.text = @"Add Payload";
                return cell;
            } else {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PayloadCell" forIndexPath:indexPath];
                Payload *payload = self.payloads[indexPath.row];
                [self configurePayloadCell:cell forPayload:payload];
                cell.textLabel.text = payload.displayName;
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%llu KiB)",
                                             [self.payloadDateFormatter stringFromDate:payload.fileDate],
                                             payload.fileSize / 1024];
                return cell;
            }
        }
    }
    return nil;
}

- (void)configureLinkCell:(UITableViewCell *)cell {
    if (self.editing) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = self.textColorInactive;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = self.textColorButton;
    }
}

- (void)configureDeviceCell:(UITableViewCell *)cell {
    cell.textLabel.text = self.usbDevice ? @"Nintendo Switch Connected" : @"No Connection";
    cell.detailTextLabel.text = self.usbStatus ?: @"Ready for APX USB device...";
}

- (NSString *)footerForDeviceCell {
    if (self.usbError) {
        return self.usbError;
    } else {
        return @"Connect your Nintendo Switch in RCM mode via a Lighting OTG adapter. An unsupported \"APX\" device warning from iOS can safely be ignored.";
    }
}

- (void)updateDeviceStatus:(NSString *)status {
    self.usbStatus = status;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:TableSectionDevice];
    [self.tableView beginUpdates];
    [self configureDeviceCell:[self.tableView cellForRowAtIndexPath:indexPath]];
    [self.tableView footerViewForSection:TableSectionDevice].textLabel.text = [self footerForDeviceCell];
    [self.tableView endUpdates];
}

- (void)configurePayloadCell:(UITableViewCell *)cell forPayload:(Payload *)payload {
    cell.accessoryType = payload == self.selectedPayload ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == TableSectionPayloads;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == TableSectionPayloads && indexPath.row != self.payloads.count;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)destIndexPath {
    if (sourceIndexPath.section > destIndexPath.section) {
        return [NSIndexPath indexPathForRow:0 inSection:sourceIndexPath.section];
    } else if (sourceIndexPath.section < destIndexPath.section || destIndexPath.row >= self.payloads.count) {
        return [NSIndexPath indexPathForRow:(self.payloads.count - 1) inSection:sourceIndexPath.section];
    } else {
        return destIndexPath;
    }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    Payload *payload = self.payloads[sourceIndexPath.row];
    [self.payloads removeObjectAtIndex:sourceIndexPath.row];
    [self.payloads insertObject:payload atIndex:destinationIndexPath.row];
    [self.payloadStorage storePayloadSortOrder:self.payloads];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.editing) {
        // Disable swipe-to-delete, assuming the user seldomly wants to delete payloads.
        return UITableViewCellEditingStyleNone;
    }
    if (indexPath.section != TableSectionPayloads) {
        return UITableViewCellEditingStyleNone;
    } else if (indexPath.row == self.payloads.count) {
        return UITableViewCellEditingStyleInsert;
    } else {
        return UITableViewCellEditingStyleDelete;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    assert(indexPath.section == TableSectionPayloads);
    if (editingStyle == UITableViewCellEditingStyleInsert) {
        [self addPayloadFromFile];
        return;
    }

    assert(editingStyle == UITableViewCellEditingStyleDelete);
    Payload *payload = self.payloads[indexPath.row];
    NSError *error = nil;
    if ([self.payloadStorage deletePayload:payload error:&error]) {
        [self.payloads removeObjectAtIndex:indexPath.row];
        [self.payloadStorage storePayloadSortOrder:self.payloads];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Deletion Failed"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isEditing && indexPath.section != TableSectionPayloads) {
        return nil; // nothing except payloads can be tapped in edit mode
    } else if (indexPath.section == TableSectionDevice) {
        return nil; // device can never be tapped
    } else {
        return indexPath;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.section) {
        case TableSectionLinks:
            switch (indexPath.row) {
                case 0:
                    [self performSegueWithIdentifier:@"GettingStarted" sender:self];
                    break;
                case 1:
                    [self performSegueWithIdentifier:@"About" sender:self];
                    break;
            }
            break;
        case TableSectionPayloads:
            if (indexPath.row == self.payloads.count) {
                [self addPayloadFromFile];
            } else {
                Payload *payload = self.payloads[indexPath.row];
                if (self.isEditing) {
                    [self renamePayload:payload];
                } else if ([self.selectedPayload isEqual:payload]) {
                    self.selectedPayload = nil;
                    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryNone;
                } else {
                    if (self.selectedPayload) {
                        [self cellForPayload:self.selectedPayload].accessoryType = UITableViewCellAccessoryNone;
                    }
                    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
                    self.selectedPayload = payload;
                    if (self.usbDevice) {
                        [self updateDeviceStatus:@"Booting payload..."];
                        [self bootPayload:payload];
                    }
                }
            }
            break;
    }
}

- (nullable UITableViewCell *)cellForPayload:(Payload *)payload {
    NSUInteger index = [self.payloads indexOfObject:payload];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)index inSection:TableSectionPayloads];
        return [self.tableView cellForRowAtIndexPath:indexPath];
    } else {
        return nil;
    }
}

- (void)renamePayload:(Payload *)payload {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename Payload"
                                                                   message:@"Enter a new name for this payload."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = payload.displayName;
        textField.placeholder = @"payload name";
        textField.clearButtonMode = UITextFieldViewModeAlways;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newName = alert.textFields[0].text;
        if (newName.length == 0 || [newName containsString:@":"] || [newName containsString:@"/"]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename Failed"
                                                                           message:@"Please enter a valid file name without the characters ':' or '/'."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        NSError *error = nil;
        if ([self.payloadStorage renamePayload:payload withNewName:newName error:&error]) {
            [self cellForPayload:payload].textLabel.text = newName;
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename Failed"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Document Picker

- (void)addPayloadFromFile {
    NSArray *docTypes = @[@"public.item", @"public.data"];
    @try {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:docTypes inMode:UIDocumentPickerModeImport];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
    @catch (NSException *exception) {
        NSString *message;
        if ([exception.name isEqualToString:NSInternalInconsistencyException]) {
            message = @"iOS 10 cannot show a file picker when NXBoot is installed from an IPA file. Please import using the iCloud Drive app or SSH. Alternatively reinstall from a classic DEB archive.";
        } else {
            message = exception.reason;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    NSError *error = nil;
    Payload *payload = [self.payloadStorage importPayload:url.path move:YES error:&error];
    if (payload) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.payloads.count inSection:TableSectionPayloads];
        [self.payloads addObject:payload];
        [self.payloadStorage storePayloadSortOrder:self.payloads];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Failed"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Navigation

- (UIBarButtonItem *)settingsButtonItem {
    if (@available(iOS 13, *)) {
        return [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                                style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(settingsButtonTapped:)];
    } else {
        return [[UIBarButtonItem alloc] initWithTitle:@"Settings"
                                                style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(settingsButtonTapped:)];
    }
}

- (void)settingsButtonTapped:(id)sender {
    [self performSegueWithIdentifier:@"Settings" sender:self];
}

- (IBAction)settingsUnwindAction:(UIStoryboardSegue *)unwindSegue {}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (self.selectedPayload) {
        [self cellForPayload:self.selectedPayload].accessoryType = UITableViewCellAccessoryNone;
        self.selectedPayload = nil;
    }
}

#pragma mark - NXUSBDeviceEnumeratorDelegate

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceConnected:(NXUSBDevice *)device {
    self.usbDevice = device;
    if (self.selectedPayload) {
        [self updateDeviceStatus:@"Connected, booting payload..."];
        [self bootPayload:self.selectedPayload];
    } else {
        [self updateDeviceStatus:@"No payload activated yet"];
    }
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(NXUSBDevice *)device {
    self.usbDevice = nil;
    [self updateDeviceStatus:@"Disconnected"];
}

- (void)usbDeviceEnumerator:(NXUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {
    self.usbError = err;
    [self updateDeviceStatus:@"USB device error"];
}

@end
