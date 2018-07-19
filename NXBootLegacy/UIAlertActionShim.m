/**
 * @file UIAlertController for iOS 7 helper
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "UIAlertActionShim.h"

@implementation UIAlertActionShim

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(UIAlertActionStyleShim)style
                        handler:(void(^)(UIAlertActionShim *action))handler
{
    UIAlertActionShim *action = [[self alloc] init];
    action.title = title;
    action.style = style;
    action.handler = handler;
    return action;
}

@end
