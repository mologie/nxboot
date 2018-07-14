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
    self.versionLabel.text = [NSString stringWithFormat:@"Version %@", info[@"CFBundleShortVersionString"]];
}

- (IBAction)homepageButtonTapped:(id)sender {
    NSURL *homepageURL = [NSURL URLWithString:@"https://mologie.github.io/nxboot/"];
    [[UIApplication sharedApplication] openURL:homepageURL options:@{} completionHandler:nil];
}

@end
