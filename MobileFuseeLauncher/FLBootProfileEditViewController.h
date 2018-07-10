/**
 * @file create or edit a single boot profile
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <UIKit/UIKit.h>
#import "FLBootProfile+CoreDataClass.h"

@interface FLBootProfileEditViewController : UITableViewController
@property (nonatomic, strong) FLBootProfile *profile;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (assign, nonatomic, readonly) BOOL isNewProfile;
- (void)save;
@end
