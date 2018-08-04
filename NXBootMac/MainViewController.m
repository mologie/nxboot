/**
 * @file main window view controller
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "MainViewController.h"
#import "CheckboxCellView.h"
#import "NXExec.h"
#import "NXUSBDevice.h"
#import "NXUSBDeviceEnumerator.h"

@interface MainViewController () <NSTableViewDelegate, NSTableViewDataSource>
@property (weak) IBOutlet NSVisualEffectView *backgroundView;
@property (weak) IBOutlet NSTextField *versionLabel;
@property (weak) IBOutlet NSScrollView *tableView;
@property (weak) IBOutlet NSImageView *statusImage;
@property (weak) IBOutlet NSTextField *statusLabel;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    self.view.window.movableByWindowBackground = YES;
    self.view.window.appearance = self.backgroundView.appearance;
}

#pragma mark - Actions

- (IBAction)tableButtonClicked:(id)sender {
}

- (IBAction)bootNowClicked:(id)sender {
}

#pragma mark - Table View

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return 1;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableColumn == tableView.tableColumns[0]) {
        CheckboxCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.checkbox.state = NSControlStateValueOff;
        return cell;
    }
    else if (tableColumn == tableView.tableColumns[1]) {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.textField.stringValue = @"Fusée Demo";
        return cell;
    }
    else if (tableColumn == tableView.tableColumns[2]) {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.textField.stringValue = @"intermezzio";
        return cell;
    }
    else if (tableColumn == tableView.tableColumns[3]) {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:nil];
        cell.textField.stringValue = @"fusee.bin";
        return cell;
    }
    else {
        return nil;
    }
}

@end
