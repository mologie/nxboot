/**
 * @file UIAlertController for iOS 7
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "UIAlertControllerShim.h"

@implementation UIAlertControllerShim

+ (instancetype)alertControllerWithTitle:(NSString *)title
                                 message:(NSString *)message
                          preferredStyle:(UIAlertControllerStyleShim)preferredStyle
{
    // TODO
    return nil;
}

- (void)addAction:(UIAlertActionShim *)action {
    // TODO
}

- (void)addTextFieldWithConfigurationHandler:(void(^)(UITextField *textField))configurationHandler {
    // TODO support a single text field
}

@end
