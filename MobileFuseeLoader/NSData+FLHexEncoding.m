/**
 * @file extends NSData with hexLower/-UpperCaseString methods
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import "NSData+FLHexEncoding.h"

@implementation NSData (FLHexEncoding)

- (NSString *)FL_hexFormattedStringWithFormat:(NSString *)format {
    UInt8 const *buf = self.bytes;
    NSUInteger n = self.length;
    NSMutableString *res = [[NSMutableString alloc] initWithCapacity:(n * 2)];
    for (NSUInteger i = 0; i < n; i++) {
        [res appendString:[NSString stringWithFormat:format, buf[i]]];
    }
    return res;
}

- (NSString *)FL_hexLowerCaseString {
    return [self FL_hexFormattedStringWithFormat:@"%02x"];
}

- (NSString *)FL_hexUpperCaseString {
    return [self FL_hexFormattedStringWithFormat:@"%02X"];
}

@end
