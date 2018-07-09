/**
 * @file coordinates GUI and exploit implementation
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "FLMainViewController.h"
#import "FLExec.h"
#import "FLUSBDeviceEnumerator.h"

#define kTegraNintendoSwitchVendorID  0x0955
#define kTegraNintendoSwitchProductID 0x7321

@interface FLMainViewController () <FLUSBDeviceEnumeratorDelegate>
@property (strong, nonatomic) FLUSBDeviceEnumerator *usbEnum;
@property (strong, nonatomic) FLUSBDevice *device;
@property (strong, nonatomic) NSString *bootStatus;
@property (strong, nonatomic) NSString *bootNowText;
@property (weak, nonatomic) IBOutlet UILabel *bootButtonLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *bootActivityIndicator;
@property (assign, nonatomic) BOOL active;
@end

@implementation FLMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];

    self.bootNowText = self.bootButtonLabel.text;
    [self setIdleBootStatus];

    self.usbEnum = [[FLUSBDeviceEnumerator alloc] init];
    self.usbEnum.delegate = self;
    [self.usbEnum addFilterForVendorID:kTegraNintendoSwitchVendorID productID:kTegraNintendoSwitchProductID];
    [self.usbEnum start];
}

- (void)dealloc {
    [self.usbEnum stop];
}

#pragma mark - Properties

- (void)setBootStatus:(NSString *)bootStatus {
    _bootStatus = bootStatus;
    [UIView setAnimationsEnabled:NO];
    [self.tableView beginUpdates];
    [self setTableSection:2 footerText:bootStatus];
    [self.tableView endUpdates];
    [UIView setAnimationsEnabled:YES];
}

- (void)setIdleBootStatus {
    if (self.device) {
        self.bootStatus = @"Device connected! Tap the Boot Now button to start.";
    }
    else {
        self.bootStatus = @"No Tegra device in RCM mode was connected yet. "
            "Connect a device using a USB Type C to Lightning cable or adapter and tap the above button.";
    }
}

#pragma mark - Table View

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2 && indexPath.row == 0) {
        if (!self.active) {
            [self bootStart];
        }
        else {
            [self bootStop];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) {
        return self.bootStatus;
    }
    return [super tableView:tableView titleForFooterInSection:section];
}

- (void)setTableSection:(NSInteger)section footerText:(NSString *)text {
    UITableViewHeaderFooterView *sectionFooterView = [self.tableView footerViewForSection:section];
    UILabel *label = sectionFooterView.textLabel;
    label.text = text;
    label.numberOfLines = 0;
    CGSize newSize = [label sizeThatFits:label.frame.size];
    CGRect newFrame = label.frame;
    newFrame.size.height = newSize.height; // discard width
    label.frame = newFrame;
}

#pragma mark - Tegra Device Interaction

- (void)bootStart {
    [self.bootActivityIndicator startAnimating];
    self.bootButtonLabel.text = @"Active - Tap to Stop";
    self.active = YES;

    if (self.device) {
        [self bootExecSelected];
    }
    else {
        self.bootStatus = @"Waiting for Tegra device in RCM mode...";
    }
}

- (void)bootExecSelected {
    assert(self.device != nil);
    self.bootStatus = @"Device connected! Booting...";

    // TODO run in a thread/queue? if so:
    // TODO when reporting status ensure that self.device still matches
    // TODO keep a week handle to device and compare to nil!
    NSString *err = nil;
    if (!FLExec(self.device->_intf, [self fuseeRelocator], [self fuseeBootImage], &err)) {
        self.bootStatus = [NSString stringWithFormat:@"Error: %@", err];
    }
}

- (void)bootStop {
    [self.bootActivityIndicator stopAnimating];
    [self setIdleBootStatus];
    self.bootButtonLabel.text = self.bootNowText;
    self.active = NO;
}

- (NSData *)fuseeRelocator {
    // TODO select file from config
    return [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"intermezzo.bin" ofType:nil]];
}

- (NSData *)fuseeBootImage {
    // TODO select file from config
    return [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"fusee.bin" ofType:nil]];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // TODO stop automatic booting only if we're switching to the config screen?
    [self bootStop];
}

#pragma mark - FLUSBDeviceEnumeratorDelegate

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceConnected:(FLUSBDevice *)device {
    self.device = device;
    if (self.active) {
        [self bootExecSelected];
    }
}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceDisconnected:(FLUSBDevice *)device {
    self.device = nil;
    self.bootStatus = @"Device disconnected. Waiting for next connection...";
}

- (void)usbDeviceEnumerator:(FLUSBDeviceEnumerator *)deviceEnum deviceError:(NSString *)err {
    self.bootStatus = [NSString stringWithFormat:@"Connection error: %@", err];
}

@end
