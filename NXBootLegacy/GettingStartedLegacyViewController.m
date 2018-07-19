/**
 * @file displays tutorials for the application
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "GettingStartedLegacyViewController.h"
#import <WebKit/WebKit.h>

@interface GettingStartedLegacyViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *browserBackButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *browserForwardButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *browserReloadButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) NSURL *startURL;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@end

@implementation GettingStartedLegacyViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.startURL = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html" subdirectory:@"Tutorial"];

    [self.webView addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"canGoForward" options:NSKeyValueObservingOptionNew context:nil];
    self.browserBackButton.enabled = NO;
    self.browserForwardButton.enabled = NO;

    [self.webView loadRequest:[NSURLRequest requestWithURL:self.startURL]];
}

- (void)dealloc {
    [self.webView removeObserver:self forKeyPath:@"loading"];
    [self.webView removeObserver:self forKeyPath:@"canGoBack"];
    [self.webView removeObserver:self forKeyPath:@"canGoForward"];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.webView && [keyPath isEqualToString:@"loading"]) {
        if (self.webView.loading) {
            [self.activityIndicatorView startAnimating];
        }
        else {
            [self.activityIndicatorView stopAnimating];
        }
    }
    else if (object == self.webView && [keyPath isEqualToString:@"canGoBack"]) {
        self.browserBackButton.enabled = self.webView.canGoBack;
    }
    else if (object == self.webView && [keyPath isEqualToString:@"canGoForward"]) {
        self.browserForwardButton.enabled = self.webView.canGoForward;
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Actions

- (IBAction)browserBackButtonTapped:(id)sender {
    [self.webView goBack];
}

- (IBAction)browserForwardButtonTapped:(id)sender {
    [self.webView goForward];
}

- (IBAction)browserReloadButtonTapped:(id)sender {
    if (self.webView.request.URL.absoluteString) {
        [self.webView reload];
    }
    else {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.startURL]];
    }
}

@end
