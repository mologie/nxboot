/**
 * @file create or edit a single boot profile
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Cocoa/Cocoa.h>
#import "BootProfile+CoreDataClass.h"

@interface BootProfileEditViewController : NSViewController
@property (nonatomic, strong) BootProfile *profile;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (assign, nonatomic, readonly) BOOL isNewProfile;
- (void)save;
@end
