import UIKit
import UniformTypeIdentifiers
import CoreServices
import ImageIO
import Photos

@objc class Converter4Image : NSObject {
    private let kFigAppleMakerNote_AssetIdentifier = "17"
    private let image : UIImage

    @objc init(image : UIImage) {
        self.image = image
    }

    @objc func read() -> String? {
        guard let makerNote = metadata(index: 0)?.object(forKey: kCGImagePropertyMakerAppleDictionary) as? NSDictionary else {
            return nil
        }
        return makerNote.object(forKey: kFigAppleMakerNote_AssetIdentifier) as? String
    }

    @objc func write(dest : String, assetIdentifier : String) {
        guard let destURL = URL(fileURLWithPath: dest) as CFURL?,
              let dest = CGImageDestinationCreateWithURL(destURL, UTType.heic.identifier as CFString, 1, nil) else { return }
        defer { CGImageDestinationFinalize(dest) }
        for i in 0...0 {
            guard let imageSource = self.imageSource() else { return }
            guard let metadata = self.metadata(index: i)?.mutableCopy() as? NSMutableDictionary else { return }
            
            let makerNote = NSMutableDictionary()
            makerNote.setObject(assetIdentifier, forKey: kFigAppleMakerNote_AssetIdentifier as NSCopying)
            metadata.setObject(makerNote, forKey: kCGImagePropertyMakerAppleDictionary as NSString)
//            metadata.setObject("sRGB IEC61966-2.1", forKey: kCGImagePropertyProfileName as NSString)
            CGImageDestinationAddImageFromSource(dest, imageSource, i, metadata as CFDictionary)
        }
    }

    private func metadata(index: Int) -> NSDictionary? {
        return self.imageSource().flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, index, nil) as NSDictionary?
        }
    }

    private func imageSource() -> CGImageSource? {
        return self.data().flatMap {
            CGImageSourceCreateWithData($0 as CFData, nil)
        }
    }

    private func data() -> Data? {
        if #available(iOS 17.0, *) {
            return image.heicData()
        } else {
            return image.pngData()
        }
    }
}
