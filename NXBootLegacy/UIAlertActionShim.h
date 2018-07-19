/**
 * @file UIAlertController for iOS 7 helper
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, UIAlertActionStyleShim) {
    UIAlertActionStyleShimDefault = 0,
    UIAlertActionStyleShimCancel,
    UIAlertActionStyleShimDestructive
};

@interface UIAlertActionShim : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic) UIAlertActionStyleShim style;
@property (nonatomic, copy) void(^handler)(UIAlertActionShim *);

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(UIAlertActionStyleShim)style
                        handler:(void(^)(UIAlertActionShim *action))handler;

@end
