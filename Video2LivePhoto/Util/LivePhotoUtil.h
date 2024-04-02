#import <Foundation/Foundation.h>

@interface LivePhotoUtil : NSObject

+ (void)convertVideo:(NSString*)path complete:(void(^)(BOOL, NSString*))complete;

@end
