//
//  FLCmdTool.h
//  MobileFuseeLoader
//
//  Created by Oliver Kuckertz on 07.07.18.
//  Copyright © 2018 Oliver Kuckertz. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLCmdTool : NSObject
@property (strong, nonatomic) NSData *relocator;
@property (strong, nonatomic) NSData *image;
- (void)start;
@end
