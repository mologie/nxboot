/**
 * @file UIAlertController for iOS 7
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <UIKit/UIKit.h>
#import "UIAlertActionShim.h"

typedef NS_ENUM(NSInteger, UIAlertControllerStyleShim) {
    UIAlertControllerStyleShimActionSheet = 0,
    UIAlertControllerStyleShimAlert
};

@interface UIAlertControllerShim : UIViewController

@property (nonatomic, strong) NSString *alertTitle;
@property (nonatomic, strong) NSString *alertMessage;
@property (nonatomic, strong) NSArray<UIAlertActionShim *> *actions;
@property (nonatomic, strong) NSArray<UITextField *> *textFields;

+ (instancetype)alertControllerWithTitle:(NSString *)title
                                 message:(NSString *)message
                          preferredStyle:(UIAlertControllerStyleShim)preferredStyle;

- (void)addAction:(UIAlertActionShim *)action;
- (void)addTextFieldWithConfigurationHandler:(void(^)(UITextField *textField))configurationHandler;

@end
