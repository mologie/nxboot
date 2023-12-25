#import "SwitchTableViewCell.h"

@implementation SwitchTableViewCell

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.customSwitch removeTarget:nil action:nil forControlEvents:UIControlEventTouchUpInside];
}

@end
