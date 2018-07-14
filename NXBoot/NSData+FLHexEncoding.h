/**
 * @file extends NSData with hexLower/-UpperCaseString methods
 * @author Oliver Kuckertz <oliver.kuckertz@mologie.de>
 */

#import <Foundation/Foundation.h>

@interface NSData (FLHexEncoding)
- (NSString *)FL_hexFormattedStringWithFormat:(NSString *)format;
- (NSString *)FL_hexLowerCaseString;
- (NSString *)FL_hexUpperCaseString;
@end
