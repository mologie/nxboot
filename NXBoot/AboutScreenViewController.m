/**
 * @file about screen controller
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "AboutScreenViewController.h"

@interface AboutScreenViewController ()
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@end

@implementation AboutScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
#ifndef NXBOOT_LEGACY
    self.versionLabel.text = [NSString stringWithFormat:@"Version %@", info[@"CFBundleShortVersionString"]];
#else
    self.versionLabel.text = [NSString stringWithFormat:@"Legacy Version %@", info[@"CFBundleShortVersionString"]];
#endif
}

- (IBAction)homepageButtonTapped:(id)sender {
    NSURL *homepageURL = [NSURL URLWithString:@"https://mologie.github.io/nxboot/"];
#ifndef NXBOOT_LEGACY
    [[UIApplication sharedApplication] openURL:homepageURL options:@{} completionHandler:nil];
#else
    [[UIApplication sharedApplication] openURL:homepageURL];
#endif
}

@end
