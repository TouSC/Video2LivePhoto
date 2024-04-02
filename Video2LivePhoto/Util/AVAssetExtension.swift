import AVKit

extension AVAsset {
    func countFrames(exact:Bool) -> Int {
        
        var frameCount = 0
        
        if let videoReader = try? AVAssetReader(asset: self)  {
            
            if let videoTrack = self.tracks(withMediaType: .video).first {
                
                frameCount = Int(CMTimeGetSeconds(self.duration) * Float64(videoTrack.nominalFrameRate))
                
                
                if exact {
                    
                    frameCount = 0
                    
                    let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
                    videoReader.add(videoReaderOutput)
                    
                    videoReader.startReading()
                    
                    // count frames
                    while true {
                        let sampleBuffer = videoReaderOutput.copyNextSampleBuffer()
                        if sampleBuffer == nil {
                            break
                        }
                        frameCount += 1
                    }
                    
                    videoReader.cancelReading()
                }
                
                
            }
        }
        
        return frameCount
    }
    
    func stillImageTime() -> CMTime?  {
        
        var stillTime:CMTime? = nil
        
        if let videoReader = try? AVAssetReader(asset: self)  {
            
            if let metadataTrack = self.tracks(withMediaType: .metadata).first {
                
                let videoReaderOutput = AVAssetReaderTrackOutput(track: metadataTrack, outputSettings: nil)
                
                videoReader.add(videoReaderOutput)
                
                videoReader.startReading()
                
                let keyStillImageTime = "com.apple.quicktime.still-image-time"
                let keySpaceQuickTimeMetadata = "mdta"
                
                var found = false
                
                while found == false {
                    if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                        if CMSampleBufferGetNumSamples(sampleBuffer) != 0 {
                            let group = AVTimedMetadataGroup(sampleBuffer: sampleBuffer)
                            for item in group?.items ?? [] {
                                if item.key as? String == keyStillImageTime && item.keySpace!.rawValue == keySpaceQuickTimeMetadata {
                                    stillTime = group?.timeRange.start
                                    //print("stillImageTime = \(CMTimeGetSeconds(stillTime!))")
                                    found = true
                                    break
                                }
                            }
                        }
                    }
                    else {
                        break;
                    }
                }
                
                videoReader.cancelReading()
                
            }
        }
        
        return stillTime
    }
    
    func makeStillImageTimeRange(percent:Float, inFrameCount:Int = 0) -> CMTimeRange {
        
        var time = self.duration
        
        var frameCount = inFrameCount
        
        if frameCount == 0 {
            frameCount = self.countFrames(exact: true)
        }
        
        let frameDuration = Int64(Float(time.value) / Float(frameCount))
        
        time.value = Int64(Float(time.value) * percent)
        
        //print("stillImageTime = \(CMTimeGetSeconds(time))")
        
        return CMTimeRangeMake(start: time, duration: CMTimeMake(value: frameDuration, timescale: time.timescale))
    }
    
    func getAssetFrame(percent:Float) -> UIImage?
    {
        
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true
        
        imageGenerator.requestedTimeToleranceAfter = CMTimeMake(value: 1,timescale: 100)
        imageGenerator.requestedTimeToleranceBefore = CMTimeMake(value: 1,timescale: 100)
        
        var time = self.duration
        
        time.value = Int64(Float(time.value) * percent)
        
        do {
            var actualTime = CMTime.zero
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime:&actualTime)
            
            let img = UIImage(cgImage: imageRef)
            
            return img
        }
        catch let error as NSError
        {
            print("Image generation failed with error \(error)")
            return nil
        }
    }
}

