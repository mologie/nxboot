#import "SettingsViewController.h"
#import "Settings.h"
#import "SwitchTableViewCell.h"

@interface SettingsViewController ()

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        //case 0: return @"Enable to keep payloads in sync between your iOS and macOS devices.";
        case 0: return @"Crash reports help me to find issues on various jailbreaks that NXBoot is used with. Reports are anonymous and do not contain any user data.";
        case 1: return @"Usage data tells me how often NXBoot is being used to boot payloads. This gives me a fuzzy feeling and lets me know which iOS versions and devices it already works on.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SwitchTableViewCell" forIndexPath:indexPath];
    switch (indexPath.section) {
        /*
        case 0:
            cell.customLabel.text = @"Use iCloud";
            cell.customSwitch.on = Settings.enableSync;
            [cell.customSwitch addTarget:self
                                  action:@selector(setEnableSync:)
                        forControlEvents:UIControlEventTouchUpInside];
            break;
        */
        case 0:
            cell.customLabel.text = @"Allow crash reports";
            cell.customSwitch.on = Settings.enableCrashReports;
            [cell.customSwitch addTarget:self
                                  action:@selector(setEnableCrashReports:)
                        forControlEvents:UIControlEventTouchUpInside];
            break;
        case 1:
            cell.customLabel.text = @"Allow usage pings";
            cell.customSwitch.on = Settings.enableUsagePings;
            [cell.customSwitch addTarget:self
                                  action:@selector(setEnableUsagePings:)
                        forControlEvents:UIControlEventTouchUpInside];
            break;
    }
    return cell;
}

#pragma mark - Switch actions

/*
- (void)setEnableSync:(UISwitch *)sender {
    Settings.enableSync = sender.on;
}
*/

- (void)setEnableCrashReports:(UISwitch *)sender {
    Settings.enableCrashReports = sender.on;
}

- (void)setEnableUsagePings:(UISwitch *)sender {
    Settings.enableUsagePings = sender.on;
}

@end
