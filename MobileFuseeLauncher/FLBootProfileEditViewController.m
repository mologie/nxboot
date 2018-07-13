/**
 * @file create or edit a single boot profile
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "FLBootProfileEditViewController.h"

enum {
    kSectionName = 0,
    kSectionRelocator = 1,
    kSectionPayload = 2
};

enum {
    kMaxRelocatorSize = 3648
};

@interface FLBootProfileEditViewController () <UIDocumentPickerDelegate>
@property (assign, nonatomic) BOOL isNewProfile;
@property (strong, nonatomic) NSArray<NSString *> *builtInRelocators;
@property (strong, nonatomic) NSArray<NSString *> *builtInPayloads;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (copy, nonatomic) void(^nextFilePromptCompletionHandler)(NSURL *url);
@property (strong, nonatomic) NSURL *relocatorUrlToDeleteOnSave;
@property (strong, nonatomic) NSURL *payloadUrlToDeleteOnSave;
@end

@implementation FLBootProfileEditViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];

    self.builtInRelocators = @[@"intermezzo.bin"];
    self.builtInPayloads = @[@"fusee.bin"];

    // create a new profile if none was specified
    if (!self.profile) {
        self.isNewProfile = YES;
        self.title = @"Add Profile";
        self.profile = [[FLBootProfile alloc] initWithEntity:[FLBootProfile entity] insertIntoManagedObjectContext:nil];
        self.profile.name = @"New Profile";
        self.profile.relocatorName = @"intermezzo.bin"; // empty relocatorBin, thus main bundle's Payloads/ is searched
        self.saveButton.enabled = NO; // user must select a payload first
    }
}

- (void)save {
    // write to managed object store
    if (self.isNewProfile) {
        [self.managedObjectContext insertObject:self.profile];
    }
    NSError *error = nil;
    if (![self.managedObjectContext save:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn't Save Profile"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // purge imported files from iTunes' documents directory
    if (self.relocatorUrlToDeleteOnSave) {
        [[NSFileManager defaultManager] removeItemAtURL:self.relocatorUrlToDeleteOnSave error:nil];
        self.relocatorUrlToDeleteOnSave = nil;
    }
    if (self.payloadUrlToDeleteOnSave) {
        [[NSFileManager defaultManager] removeItemAtURL:self.payloadUrlToDeleteOnSave error:nil];
        self.payloadUrlToDeleteOnSave = nil;
    }
}

- (void)updateSaveButton {
    self.saveButton.enabled =
        self.profile.name.length > 0 &&
        self.profile.payloadName.length > 0 &&
        self.profile.relocatorName.length > 0;
}

#pragma mark - Table

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    switch (indexPath.section) {
        case 0: {
            // name
            cell.detailTextLabel.text = self.profile.name;
            break;
        }
        case 1: {
            // relocator
            if (self.profile.relocatorName.length == 0) {
                cell.detailTextLabel.text = @"(required)";
            }
            else if (self.profile.relocatorBin.length == 0) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"built-in: %@", self.profile.relocatorName];
            }
            else {
                cell.detailTextLabel.text = self.profile.relocatorName;
            }
            break;
        }
        case 2: {
            // payload
            if (self.profile.payloadName.length == 0) {
                cell.detailTextLabel.text = @"(required)";
            }
            else if (self.profile.payloadBin.length == 0) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"built-in: %@", self.profile.payloadName];
            }
            else {
                cell.detailTextLabel.text = self.profile.payloadName;
            }
            break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.section) {
        case 0: {
            // edit name
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Edit Name"
                                                                           message:@"Enter a new name for this profile."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.text = self.profile.name;
                textField.placeholder = @"profile name";
                textField.clearButtonMode = UITextFieldViewModeAlways;
            }];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *profileName = alert.textFields[0].text;
                self.profile.name = profileName;
                [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSectionName]].detailTextLabel.text = profileName;
                [self updateSaveButton];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
            break;
        }
        case 1: {
            // edit relocator
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select Relocator"
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
            for (NSString *relocatorName in self.builtInRelocators) {
                NSString *title = [NSString stringWithFormat:@"Built-In: %@", relocatorName];
                [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    self.profile.relocatorName = relocatorName;
                    self.profile.relocatorBin = nil;
                    self.relocatorUrlToDeleteOnSave = nil;
                    NSString *detailText = [NSString stringWithFormat:@"built-in: %@", relocatorName];
                    [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSectionRelocator]].detailTextLabel.text = detailText;
                    [self updateSaveButton];
                }]];
            }
            for (NSURL *docUrl in self.importedFiles) {
                NSString *title = [NSString stringWithFormat:@"Imported: %@", docUrl.lastPathComponent];
                [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    NSData *doc = [NSData dataWithContentsOfURL:docUrl];
                    if (doc.length > 0 && doc.length <= kMaxRelocatorSize) {
                        NSString *name = docUrl.lastPathComponent;
                        self.profile.relocatorName = name;
                        self.profile.relocatorBin = doc;
                        self.relocatorUrlToDeleteOnSave = docUrl;
                        [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSectionRelocator]].detailTextLabel.text = name;
                        [self updateSaveButton];
                        [self presentAlertWithTitle:@"Imported File" message:@"Note: The selected relocator is removed from the imported files list when the profile is saved."];
                    }
                    else if (doc.length > kMaxRelocatorSize) {
                        [self presentAlertWithTitle:@"Error" message:@"The selected relocator binary is too large. Did you select the right file?"];
                    }
                    else {
                        [self presentAlertWithTitle:@"Error" message:@"Import failed, no data is available at the import path."];
                    }
                }]];
            }
            [alert addAction:[UIAlertAction actionWithTitle:@"Import from Files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self promptFileSelectionWithCompletion:^(NSURL *url) {
                    if (url) {
                        NSData *doc = [NSData dataWithContentsOfURL:url];
                        if (doc.length > 0 && doc.length <= kMaxRelocatorSize) {
                            NSString *name = url.lastPathComponent;
                            self.profile.relocatorName = name;
                            self.profile.relocatorBin = doc;
                            self.relocatorUrlToDeleteOnSave = nil;
                            [[NSFileManager defaultManager] removeItemAtURL:url error:nil]; // discard in-sandbox copy of the file
                            [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSectionRelocator]].detailTextLabel.text = name;
                            [self updateSaveButton];
                        }
                        else if (doc.length > kMaxRelocatorSize) {
                            [self presentAlertWithTitle:@"Error" message:@"The selected relocator binary is too large. Did you select the right file?"];
                        }
                        else {
                            [self presentAlertWithTitle:@"Error" message:@"File import failed, no data is available at the import path."];
                        }
                    }
                }];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
            [self presentViewController:alert animated:YES completion:nil];
            break;
        }
        case 2: {
            // edit payload
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select Payload"
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
            /*
            Disabled for now: We're not providing any user-visible payloads with the app; the Fusée demo entry is created by setup code.
            for (NSString *payloadName in self.builtInPayloads) {
                NSString *title = [NSString stringWithFormat:@"Built-In: %@", payloadName];
                [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    self.profile.payloadName = payloadName;
                    self.profile.payloadBin = nil;
                    self.payloadUrlToDeleteOnSave = nil;
                    NSString *detailText = [NSString stringWithFormat:@"built-in: %@", payloadName];
                    [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSectionPayload]].detailTextLabel.text = detailText;
                    [self updateSaveButton];
                }]];
            }
            */
            for (NSURL *docUrl in self.importedFiles) {
                NSString *title = [NSString stringWithFormat:@"Imported: %@", docUrl.lastPathComponent];
                [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    NSData *doc = [NSData dataWithContentsOfURL:docUrl];
                    if (doc.length > 0) {
                        NSString *name = docUrl.lastPathComponent;
                        self.profile.payloadName = name;
                        self.profile.payloadBin = doc;
                        self.payloadUrlToDeleteOnSave = docUrl;
                        [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSectionPayload]].detailTextLabel.text = name;
                        [self updateSaveButton];
                        [self presentAlertWithTitle:@"Imported File" message:@"Note: The selected payload is removed from the imported files list when the profile is saved."];
                    }
                    else {
                        [self presentAlertWithTitle:@"Error" message:@"iTunes import failed, no data is available at the import path."];
                    }
                }]];
            }
            [alert addAction:[UIAlertAction actionWithTitle:@"Import from Files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self promptFileSelectionWithCompletion:^(NSURL *url) {
                    if (url) {
                        NSData *doc = [NSData dataWithContentsOfURL:url];
                        if (doc.length > 0) {
                            NSString *name = url.lastPathComponent;
                            self.profile.payloadName = name;
                            self.profile.payloadBin = doc;
                            self.payloadUrlToDeleteOnSave = nil;
                            [[NSFileManager defaultManager] removeItemAtURL:url error:nil]; // discard in-sandbox copy of the file
                            [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSectionPayload]].detailTextLabel.text = name;
                            [self updateSaveButton];
                        }
                        else {
                            [self presentAlertWithTitle:@"Error" message:@"Import failed, no data is available at the import path."];
                        }
                    }
                }];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            alert.popoverPresentationController.sourceView = self.tableView;
            alert.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
            [self presentViewController:alert animated:YES completion:nil];
            break;
        }
    }
}

#pragma mark - File Selection (iOS 10 and later)

- (void)promptFileSelectionWithCompletion:(void(^)(NSURL *))completionBlock {
    NSArray *docTypes = @[@"public.item", @"public.data"];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:docTypes inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    self.nextFilePromptCompletionHandler = completionBlock;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    if (self.nextFilePromptCompletionHandler) {
        self.nextFilePromptCompletionHandler(url);
        self.nextFilePromptCompletionHandler = nil;
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    if (self.nextFilePromptCompletionHandler) {
        self.nextFilePromptCompletionHandler(nil);
        self.nextFilePromptCompletionHandler = nil;
    }
}

#pragma mark - Imported Files

- (NSArray<NSURL *> *)importedFiles {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *documentsDir = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [fm contentsOfDirectoryAtURL:documentsDir includingPropertiesForKeys:nil options:0 error:nil];
}

#pragma mark - UI Misc

- (void)presentAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
