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
#ifdef HAVE_SENTRY
    return 2;
#else
    return 0;
#endif
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        //case 0: return @"Enable to keep payloads in sync between your iOS and macOS devices.";
        case 0: return @"Anonymously send back crash information with minimal system data to Sentry. No data is sent until a crash happens.";
        case 1: return @"Let NXBoot count how often it is used, and anonymously report successful or failed boot events to Sentry.";
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
#ifdef HAVE_SENTRY
        case 0:
            cell.customLabel.text = @"Allow crash reports";
            cell.customSwitch.on = Settings.allowCrashReports;
            [cell.customSwitch addTarget:self
                                  action:@selector(setAllowCrashReports:)
                        forControlEvents:UIControlEventTouchUpInside];
            break;
        case 1:
            cell.customLabel.text = @"Allow usage pings";
            cell.customSwitch.on = Settings.allowUsagePings;
            [cell.customSwitch addTarget:self
                                  action:@selector(setAllowUsagePings:)
                        forControlEvents:UIControlEventTouchUpInside];
            break;
#endif
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
#ifdef HAVE_SENTRY
    Settings.allowCrashReports = sender.on;
#endif
}

- (void)setEnableUsagePings:(UISwitch *)sender {
#ifdef HAVE_SENTRY
    Settings.allowUsagePings = sender.on;
#endif
}

@end
