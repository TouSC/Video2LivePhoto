import Foundation
import AVFoundation

@objc class Converter4Video : NSObject {
    private let kKeyContentIdentifier =  "com.apple.quicktime.content.identifier"
    private let kKeyStillImageTime = "com.apple.quicktime.still-image-time"
    private let kKeySpaceQuickTimeMetadata = "mdta"
    private let path : String

    private lazy var asset : AVURLAsset = {
        let url = NSURL(fileURLWithPath: self.path)
        return AVURLAsset(url: url as URL)
    }()

    @objc init(path : String) {
        self.path = path
    }

    @objc func readAssetIdentifier() -> String? {
        for item in metadata() {
            if item.key as? String == kKeyContentIdentifier &&
                item.keySpace?.rawValue == kKeySpaceQuickTimeMetadata {
                return item.value as? String
            }
        }
        return nil
    }
    
    private func reader(track: AVAssetTrack, settings: [String:AnyObject]?) throws -> (AVAssetReader, AVAssetReaderOutput) {
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        let reader = try AVAssetReader(asset: asset)
        reader.add(output)
        return (reader, output)
    }

//    func readStillImageTime() -> NSNumber? {
//        if let track = track(mediaType: AVMediaType.metadata.rawValue) {
//            let (reader, output) = try! self.reader(track: track, settings: nil)
//            reader.startReading()
//
//            while true {
//                guard let buffer = output.copyNextSampleBuffer() else { return nil }
//                if CMSampleBufferGetNumSamples(buffer) != 0 {
//                    let group = AVTimedMetadataGroup(sampleBuffer: buffer)
//                    for item in group?.items ?? [] {
//                        if item.key as? String == kKeyStillImageTime &&
//                            item.keySpace?.rawValue == kKeySpaceQuickTimeMetadata {
//                                return item.numberValue
//                        }
//                    }
//                }
//            }
//        }
//        return nil
//    }
    
    private func createMetadataAdaptorForStillImageTime() -> AVAssetWriterInputMetadataAdaptor {
        let keyStillImageTime = "com.apple.quicktime.still-image-time"
        let keySpaceQuickTimeMetadata = "mdta"
        let spec : NSDictionary = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString:
            "\(keySpaceQuickTimeMetadata)/\(keyStillImageTime)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString:
            "com.apple.metadata.datatype.int8"            ]
        var desc : CMFormatDescription? = nil
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: [spec] as CFArray, formatDescriptionOut: &desc)
        let input = AVAssetWriterInput(mediaType: .metadata,
                                       outputSettings: nil, sourceFormatHint: desc)
        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }
    
    private func metadataForAssetID(_ assetIdentifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        let keyContentIdentifier =  "com.apple.quicktime.content.identifier"
        let keySpaceQuickTimeMetadata = "mdta"
        item.key = keyContentIdentifier as (NSCopying & NSObjectProtocol)?
        item.keySpace = AVMetadataKeySpace(rawValue: keySpaceQuickTimeMetadata)
        item.value = assetIdentifier as (NSCopying & NSObjectProtocol)?
        item.dataType = "com.apple.metadata.datatype.UTF-8"
        return item
    }

    private func metadataForStillImageTime() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = kKeyStillImageTime as any NSCopying & NSObjectProtocol
        item.keySpace = AVMetadataKeySpace.quickTimeMetadata
        item.value = 0 as (NSCopying & NSObjectProtocol)?
        item.dataType = kCMMetadataBaseDataType_SInt8 as String
        return item.copy() as! AVMetadataItem
    }

    @objc func write(dest: String, assetIdentifier: String, metaURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        do {
            let metadataAsset = AVURLAsset(url: metaURL)
            
            let readerVideo = try AVAssetReader(asset: asset)
            let readerMetadata = try AVAssetReader(asset: metadataAsset)
            
            let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: dest), fileType: .mov)
            
            let writingGroup = DispatchGroup()
            
            var videoIOs = [(AVAssetWriterInput, AVAssetReaderTrackOutput)]()
            var metadataIOs = [(AVAssetWriterInput, AVAssetReaderTrackOutput)]()
            
            Converter4Video.loadTracks(asset: self.asset, type: .video) { videoTracks in
                for track in videoTracks {
                    let trackReaderOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)])
                    readerVideo.add(trackReaderOutput)
                    
                    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey : AVVideoCodecType.h264, AVVideoWidthKey : track.naturalSize.width, AVVideoHeightKey : track.naturalSize.height])
                    videoInput.transform = track.preferredTransform
                    videoInput.expectsMediaDataInRealTime = true
                    writer.add(videoInput)
                    
                    videoIOs.append((videoInput, trackReaderOutput))
                }
                
                Converter4Video.loadTracks(asset: metadataAsset, type: .metadata) { metadataTracks in
                    for track in metadataTracks {
                        let trackReaderOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
                        readerMetadata.add(trackReaderOutput)
                        
                        let metadataInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil)
                        writer.add(metadataInput)
                        
                        metadataIOs.append((metadataInput, trackReaderOutput))
                    }
                    
                    writer.metadata = [self.metadataForAssetID(assetIdentifier)]
        //            let stillImageTimeMetadataAdapter = createMetadataAdaptorForStillImageTime()
        //            writer.add(stillImageTimeMetadataAdapter.assetWriterInput)
                    
                    writer.startWriting()
                    readerVideo.startReading()
                    readerMetadata.startReading()
                    writer.startSession(atSourceTime: .zero)
                    
        //            let _stillImagePercent: Float = 0.5
        //            stillImageTimeMetadataAdapter.append(AVTimedMetadataGroup(items: [metadataForStillImageTime()],timeRange: asset.makeStillImageTimeRange(percent: _stillImagePercent, inFrameCount: asset.countFrames(exact: false))))
                    
                    for (videoInput, videoOutput) in videoIOs {
                        writingGroup.enter()
                        videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "assetWriterQueue.video")) {
                            while videoInput.isReadyForMoreMediaData {
                                if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                                    videoInput.append(sampleBuffer)
                                } else {
                                    videoInput.markAsFinished()
                                    writingGroup.leave()
                                    break
                                }
                            }
                        }
                    }
                    for (metadataInput, metadataOutput) in metadataIOs {
                        writingGroup.enter()
                        metadataInput.requestMediaDataWhenReady(on: DispatchQueue(label: "assetWriterQueue.metadata")) {
                            while metadataInput.isReadyForMoreMediaData {
                                if let sampleBuffer = metadataOutput.copyNextSampleBuffer() {
                                    metadataInput.append(sampleBuffer)
                                } else {
                                    metadataInput.markAsFinished()
                                    writingGroup.leave()
                                    break
                                }
                            }
                        }
                    }
                    
                    writingGroup.notify(queue: .main) {
                        if
                            readerVideo.status == .completed &&
                            readerMetadata.status == .completed &&
                            writer.status == .writing {
                            writer.finishWriting {
                                completion(writer.status == .completed, writer.error)
                            }
                        } else {
                            if let readerError = readerVideo.error {
                                completion(false, readerError)
                            } else if let readerError = readerMetadata.error {
                                completion(false, readerError)
                            } else if let writerError = writer.error {
                                completion(false, writerError)
                            } else {
                                completion(false, NSError(domain: "VideoProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unkown error"]))
                            }
                        }
                    }
                }
            }
        } catch {
            completion(false, error)
        }
    }

    private func metadata() -> [AVMetadataItem] {
        return asset.metadata(forFormat: AVMetadataFormat.quickTimeMetadata)
    }

//    private func track(mediaType : String) -> AVAssetTrack? {
//        return asset.tracks(withMediaType: AVMediaType(rawValue: mediaType)).first
//    }
    
    @objc public static func resizeVideo(at inputPath: String, outputPath: String, outputSize: CGSize, completion: @escaping (Bool, Error?) -> Void) {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        let asset = AVAsset(url: inputURL)
        self.loadTracks(asset: asset, type: .video) { videoTracks in
            guard let videoTrack = videoTracks.first else {
                completion(false, NSError(domain: "Resize", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video track is not available"]))
                return
            }
            
            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov
            exportSession.shouldOptimizeForNetworkUse = true
            
            let videoComposition = AVMutableVideoComposition()
            videoComposition.renderSize = outputSize
            videoComposition.frameDuration = CMTime(value: 1, timescale: 60)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            
            let preferredTransform = videoTrack.preferredTransform
            let originalSize = CGSize(width: videoTrack.naturalSize.width, height: videoTrack.naturalSize.height)
            let transformedSize = originalSize.applying(preferredTransform)
            let absoluteSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
            
            let widthRatio = outputSize.width / absoluteSize.width
            let heightRatio = outputSize.height / absoluteSize.height
            let scaleFactor = min(widthRatio, heightRatio)

            let newWidth = absoluteSize.width * scaleFactor
            let newHeight = absoluteSize.height * scaleFactor

            let translateX = (outputSize.width - newWidth) / 2
            let translateY = (outputSize.height - newHeight) / 2

            let translateTransform = CGAffineTransform(translationX: translateX, y: translateY).scaledBy(x: scaleFactor, y: scaleFactor)

            layerInstruction.setTransform(translateTransform, at: .zero)
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            exportSession.videoComposition = videoComposition
            
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        completion(true, nil)
                    case .failed:
                        completion(false, exportSession.error)
                    default:
                        break
                    }
                }
            }
        }
    }
    
    @objc public static func accelerateVideo(at inputPath: String, to duration: CMTime, outputPath: String, completion: @escaping (Bool, Error?) -> Void) {
        let videoURL = URL(fileURLWithPath: inputPath)
        let asset = AVAsset(url: videoURL)

        let composition = AVMutableComposition()
        self.loadTracks(asset: asset, type: .video) { videoTracks in
            do {
                guard let videoTrack = videoTracks.first else {
                    completion(false, NSError(domain: "Accelerate", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video track is not available"]))
                    return
                }
                
                let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video,
                                                                         preferredTrackID: kCMPersistentTrackID_Invalid)
                
                try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration),
                                                            of: videoTrack,
                                                            at: .zero)
                let targetDuration = duration
                
                compositionVideoTrack?.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: asset.duration),
                                                       toDuration: targetDuration)

                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    return
                }
                
                let outputFileURL = URL(fileURLWithPath: outputPath)
                exportSession.outputURL = outputFileURL
                exportSession.outputFileType = .mov
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        completion(true, nil)
                    case .failed:
                        completion(false, exportSession.error)
                    default:
                        completion(false, NSError(domain: "VideoProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                    }
                }

            } catch {
                completion(false, error)
            }
        }
    }
    
    private static func loadTracks(asset: AVAsset, type: AVMediaType, completion: @escaping ([AVAssetTrack]) -> Void) {
        let tracksKey = #keyPath(AVAsset.tracks)
        if #available(iOS 15.0, *) {
            asset.loadTracks(withMediaType: type) { tracks, error in
                if let error = error {
                    print(error)
                }
                DispatchQueue.main.async {
                    completion(tracks ?? [])
                }
            }
        } else {
            asset.loadValuesAsynchronously(forKeys: [tracksKey]) {
                let status = asset.statusOfValue(forKey: "tracks", error: nil)
                if (status == .loaded) {
                    DispatchQueue.main.async {
                        print(asset) // <-- amazing trick
                        completion(asset.tracks(withMediaType: type))
                    }
                } else if (status == .cancelled) {
                    print("load tracks cancelled")
                } else if (status == .unknown) {
                    print("load tracks unknown")
                } else if (status == .failed) {
                    print("load tracks failed")
                }
            }
        }
    }
}
