/**
 * @file checkbox cell view
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Cocoa/Cocoa.h>

@interface CheckboxCellView : NSTableCellView
@property (weak) IBOutlet NSButton *checkbox;
@end
