/**
 * @file displays tutorials for the application
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "FLGettingStartedViewController.h"
#import <WebKit/WebKit.h>

@interface FLGettingStartedViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *browserBackButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *browserForwardButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *browserReloadButton;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) NSURL *startURL;
@property (strong, nonatomic) WKWebView *webView;
@end

@implementation FLGettingStartedViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.startURL = [[NSBundle mainBundle] URLForResource:@"index" withExtension:@"html" subdirectory:@"Tutorial"];

    self.webView = [[WKWebView alloc] init];
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.backgroundColor = self.view.backgroundColor;
    self.webView.scrollView.backgroundColor = self.view.backgroundColor;
    [self.webView addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"canGoForward" options:NSKeyValueObservingOptionNew context:nil];
    [self.view addSubview:self.webView];
    [self.view sendSubviewToBack:self.webView];
    self.browserBackButton.enabled = NO;
    self.browserForwardButton.enabled = NO;

    // expand web view under navigation bar
    [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    [self.view layoutIfNeeded];

    [self.webView loadRequest:[NSURLRequest requestWithURL:self.startURL]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // determine additional web page margin relative to safe area
    CGFloat topMargin = 0;
    CGFloat bottomMargin = self.toolbar.frame.size.height;

    if (self.webView.scrollView.contentInset.top != topMargin ||
        self.webView.scrollView.contentInset.bottom != bottomMargin)
    {
        // ensure that web page does not overlap with statusbar and toolbar
        self.webView.scrollView.contentInset = UIEdgeInsetsMake(topMargin, 0, bottomMargin, 0);

        // adjust scrollbar position
        UIEdgeInsets scrollIndicatorInsets = self.webView.scrollView.scrollIndicatorInsets;
        CGFloat scrollPadding = scrollIndicatorInsets.right;
        scrollIndicatorInsets.top = topMargin + scrollPadding;
        scrollIndicatorInsets.bottom = bottomMargin + scrollPadding;
        self.webView.scrollView.scrollIndicatorInsets = scrollIndicatorInsets;

        [self.webView layoutIfNeeded];
    }
}

- (void)dealloc {
    [self.webView removeObserver:self forKeyPath:@"loading"];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [self.webView removeObserver:self forKeyPath:@"canGoBack"];
    [self.webView removeObserver:self forKeyPath:@"canGoForward"];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.webView && [keyPath isEqualToString:@"loading"]) {
        if (self.webView.loading) {
            [self.activityIndicatorView startAnimating];
            [self.progressView setProgress:0 animated:NO];
            self.progressView.hidden = NO;
            self.progressView.alpha = 1.0;
        }
        else {
            [self.activityIndicatorView stopAnimating];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
            [UIView animateWithDuration:0.5 animations:^{
                self.progressView.alpha = 0.0;
            } completion:^(BOOL finished) {
                if (finished) {
                    self.progressView.hidden = YES;
                }
            }];
        }
    }
    else if (object == self.webView && [keyPath isEqualToString:@"estimatedProgress"]) {
        [self.progressView setProgress:self.webView.estimatedProgress animated:YES];
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
    if (self.webView.URL) {
        [self.webView reload];
    }
    else {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.startURL]];
    }
}

@end
