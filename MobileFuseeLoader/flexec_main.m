#import <CoreFoundation/CoreFoundation.h>
#import "FLCmdTool.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSString *relocatorPath = @"/jb/share/flexec/intermezzo.bin";
        NSString *imagePath = @"/jb/share/flexec/fusee.bin";

        if (argc == 3) {
            relocatorPath = [NSString stringWithUTF8String:argv[1]];
            imagePath = [NSString stringWithUTF8String:argv[2]];
        }

        NSLog(@"CMD: Using relocator %@ and image %@", relocatorPath, imagePath);
        FLCmdTool *cmdTool = [[FLCmdTool alloc] init];

        cmdTool.relocator = [NSData dataWithContentsOfFile:relocatorPath];
        if (cmdTool.relocator == nil) {
            NSLog(@"ERR: Failed to load relocator");
            return 1;
        }

        cmdTool.image = [NSData dataWithContentsOfFile:imagePath];
        if (cmdTool.image == nil) {
            NSLog(@"ERR: Failed to load image");
            return 1;
        }

        [cmdTool start];
        CFRunLoopRun();

        return 0;
    }
}
