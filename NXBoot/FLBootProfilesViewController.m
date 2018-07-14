/**
 * @file boot profiles list and editor controller
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "FLBootProfilesViewController.h"
#import "FLBootProfileEditViewController.h"
#import "FLBootProfile+CoreDataClass.h"
#import "FLConfig.h"
#import "AppDelegate.h"

@interface FLBootProfilesViewController ()
@property (nonatomic, strong) FLConfig *config;
@property (nonatomic, strong) NSMutableArray<FLBootProfile *> *profiles;
@property (nonatomic, strong) FLBootProfile *nextProfileToEdit;
@end

@implementation FLBootProfilesViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.config = [FLConfig sharedConfig];

    NSFetchRequest *fetchRequest = [FLBootProfile fetchRequest];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    self.profiles = [[self.managedObjectContext executeFetchRequest:fetchRequest error:nil] mutableCopy];
}

- (NSUInteger)indexOfProfileWithID:(NSString *)profileID {
    return [self.profiles indexOfObjectPassingTest:^BOOL(FLBootProfile *profile, NSUInteger idx, BOOL *stop) {
        return [profile.objectID.URIRepresentation.absoluteString isEqualToString:profileID];
    }];
}

#pragma mark - Config

- (NSString *)selectedProfileID {
    return self.config.selectedBootProfileID;
}

- (void)setSelectedProfileID:(NSString *)newProfileID atIndexPath:(NSIndexPath *)indexPath {
    // profile selection changed
    NSString *oldProfileID = self.selectedProfileID;
    if ([newProfileID isEqualToString:oldProfileID]) {
        return; // done, selection did not change
    }
    self.config.selectedBootProfileID = newProfileID;
    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;

    // clear previous chechmark
    NSUInteger rowToUpdate = [self indexOfProfileWithID:oldProfileID];
    if (rowToUpdate != NSNotFound) {
        NSIndexPath *updatePath = [NSIndexPath indexPathForRow:rowToUpdate inSection:1];
        [self.tableView cellForRowAtIndexPath:updatePath].accessoryType = UITableViewCellAccessoryNone;
    }
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1;
        case 1: return self.profiles.count;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            // new profile button
            return [tableView dequeueReusableCellWithIdentifier:@"AddBootProfile" forIndexPath:indexPath];
        }
        case 1: {
            // cell for a single profile
            FLBootProfile *profile = [self.profiles objectAtIndex:indexPath.row];
            NSString *profileID = profile.objectID.URIRepresentation.absoluteString;
            BOOL selected = [self.selectedProfileID isEqualToString:profileID];
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BootProfile" forIndexPath:indexPath];
            cell.textLabel.text = profile.name;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ loaded via %@", profile.payloadName, profile.relocatorName];
            cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            return cell;
        }
        default: {
            return nil;
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1) {
        return NO;
    }
    FLBootProfile *profile = [self.profiles objectAtIndex:indexPath.row];
    return !profile.isDemoProfile;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        FLBootProfile *profile = self.profiles[indexPath.row];

        // delete profile from object store
        [self.managedObjectContext deleteObject:profile];
        NSError *error = nil;
        if (![self.managedObjectContext save:&error]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn't Delete Profile"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        // remove from collection and table
        [self.profiles removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        // select a new profile if this was the selected profile
        NSString *profileID = profile.objectID.URIRepresentation.absoluteString;
        if ([self.selectedProfileID isEqualToString:profileID]) {
            [self setSelectedProfileID:self.profiles[0].objectID.URIRepresentation.absoluteString atIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        // add button tapped
        self.editing = NO;
        [self performSegueWithIdentifier:@"AddBootProfile" sender:nil];
    }
    else {
        FLBootProfile *profile = [self.profiles objectAtIndex:indexPath.row];
        if (self.tableView.isEditing) {
            // profile tapped while editing table
            if (!profile.isDemoProfile) {
                self.nextProfileToEdit = profile;
                [self performSegueWithIdentifier:@"EditBootProfile" sender:nil];
            }
        }
        else {
            // profile selection changed
            NSString *profileID = profile.objectID.URIRepresentation.absoluteString;
            [self setSelectedProfileID:profileID atIndexPath:indexPath];
        }
    }
}

#pragma mark - Core Data

- (NSManagedObjectContext *)managedObjectContext {
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    return delegate.persistentContainer.viewContext;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"AddBootProfile"]) {
        FLBootProfileEditViewController *controller = segue.destinationViewController;
        controller.managedObjectContext = self.managedObjectContext;
    }
    else if ([segue.identifier isEqualToString:@"EditBootProfile"]) {
        FLBootProfileEditViewController *controller = segue.destinationViewController;
        controller.profile = self.nextProfileToEdit;
        controller.managedObjectContext = self.managedObjectContext;
        self.nextProfileToEdit = nil;
    }
}

- (IBAction)unwindFromBootProfileEditor:(UIStoryboardSegue *)segue {
    FLBootProfileEditViewController *controller = segue.sourceViewController;

    [controller save];

    NSUInteger insertIndex = [self.profiles indexOfObject:controller.profile
                                            inSortedRange:NSMakeRange(0, self.profiles.count)
                                                  options:NSBinarySearchingInsertionIndex|NSBinarySearchingFirstEqual
                                          usingComparator:^NSComparisonResult(FLBootProfile *lhs, FLBootProfile *rhs) {
                                              return [lhs.name compare:rhs.name];
                                          }];

    NSString *profileID = controller.profile.objectID.URIRepresentation.absoluteString;

    if (controller.isNewProfile) {
        // add profile to collection and table and make it the selected profile
        [self.profiles insertObject:controller.profile atIndex:insertIndex];
        NSIndexPath *insertPath = [NSIndexPath indexPathForRow:insertIndex inSection:1];
        [self.tableView insertRowsAtIndexPaths:@[insertPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self setSelectedProfileID:profileID atIndexPath:insertPath];
    }
    else {
        // refresh and move the cell
        NSUInteger currentIndex = [self indexOfProfileWithID:profileID];
        NSIndexPath *sourcePath = [NSIndexPath indexPathForRow:currentIndex inSection:1];
        if (currentIndex != insertIndex) {
            [self.profiles removeObjectAtIndex:currentIndex];
            if (currentIndex < insertIndex) {
                insertIndex--;
            }
            [self.profiles insertObject:controller.profile atIndex:insertIndex];
            NSIndexPath *targetPath = [NSIndexPath indexPathForRow:insertIndex inSection:1];
            [self.tableView moveRowAtIndexPath:sourcePath toIndexPath:targetPath];
            [self.tableView reloadRowsAtIndexPaths:@[targetPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        else {
            [self.tableView reloadRowsAtIndexPaths:@[sourcePath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

@end
