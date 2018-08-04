//
//  ViewController.m
//  NXBootMac
//
//  Created by Oliver Kuckertz on 27.07.18.
//  Copyright © 2018 Oliver Kuckertz. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (void)viewWillAppear {
    [super viewWillAppear];
    self.view.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
