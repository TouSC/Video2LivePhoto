#import <Video2LivePhoto-Swift.h>
#import "LivePhotoUtil.h"
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

@implementation LivePhotoUtil

+ (void)convertVideo:(NSString*)path complete:(void(^)(BOOL, NSString*))complete;{
    NSLog(@"start converting");
    
    NSURL *metaURL = [NSBundle.mainBundle URLForResource:@"metadata" withExtension:@"mov"];
    CGSize livePhotoSize = CGSizeMake(1080, 1920);
    CMTime livePhotoDuration = CMTimeMake(630, 600);
    NSString *assetIdentifier = NSUUID.UUID.UUIDString;
    
    NSString *acceleratePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingString:@"/accelerate.mp4"];
    NSString *resizePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingString:@"/resize.mp4"];
    NSString *finalPath = resizePath;
    [NSFileManager.defaultManager removeItemAtPath:acceleratePath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:resizePath error:nil];

    [Converter4Video accelerateVideoAt:path to:livePhotoDuration outputPath:acceleratePath completion:^(BOOL success, NSError * error) {
        if (!success) {
            NSLog(@"accelerate failed: %@", error);
            complete(NO, error.localizedDescription);
            return;
        }
        [Converter4Video resizeVideoAt:acceleratePath outputPath:resizePath outputSize:livePhotoSize completion:^(BOOL success, NSError * error) {
            if (!success) {
                NSLog(@"resize failed: %@", error);
                complete(NO, error.localizedDescription);
                return;
            }
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:finalPath] options:nil];
            AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            generator.requestedTimeToleranceAfter = kCMTimeZero;
            generator.requestedTimeToleranceBefore = kCMTimeZero;
            CMTime time = CMTimeMakeWithSeconds(0, asset.duration.timescale);
            [generator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:time]] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
                if (image)
                {
                    NSString *picturePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingFormat:@"/%@.heic", @"live", nil];
                    NSString *videoPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingFormat:@"/%@.mov", @"live", nil];
                    [NSFileManager.defaultManager removeItemAtPath:picturePath error:nil];
                    [NSFileManager.defaultManager removeItemAtPath:videoPath error:nil];
                    
                    Converter4Image *converter4Image = [[Converter4Image alloc] initWithImage:[UIImage imageWithCGImage:image]];
                    [converter4Image writeWithDest:picturePath assetIdentifier:assetIdentifier];
                    
                    Converter4Video *coverter4Video = [[Converter4Video alloc] initWithPath:finalPath];
                    [coverter4Video writeWithDest:videoPath assetIdentifier:assetIdentifier metaURL:metaURL completion:^(BOOL success, NSError * error) {
                        if (!success) {
                            NSLog(@"merge failed: %@", error);
                            complete(NO, error.localizedDescription);
                            return;
                        }
                        [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
                            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                            NSURL *photoURL = [NSURL fileURLWithPath:picturePath];
                            NSURL *pairedVideoURL = [NSURL fileURLWithPath:videoPath];
                            [request addResourceWithType:PHAssetResourceTypePhoto fileURL:photoURL options:[PHAssetResourceCreationOptions new]];
                            [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:pairedVideoURL options:[PHAssetResourceCreationOptions new]];
                        } completionHandler:^(BOOL success, NSError * _Nullable error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                complete(error==nil, error.localizedDescription);
                            });
                        }];
                    }];
                }
            }];
        }];
    }];
}

@end
