#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SwitchTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *customLabel;
@property (weak, nonatomic) IBOutlet UISwitch *customSwitch;

@end

NS_ASSUME_NONNULL_END
