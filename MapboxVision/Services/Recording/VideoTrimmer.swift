import AVFoundation
import Foundation

private let timeScale: CMTimeScale = 600
private let fileType: AVFileType = .mp4

enum VideoTrimmerError: LocalizedError {
    case sourceNotExportable
}

final class VideoTrimmer {
    typealias TrimCompletion = (Error?) -> Void

    func trimVideo(source: String, clip: VideoClip, completion: @escaping TrimCompletion) {
        let sourceURL = URL(fileURLWithPath: source)
        let options = [
            AVURLAssetPreferPreciseDurationAndTimingKey: true,
        ]

        let asset = AVURLAsset(url: sourceURL, options: options)
        guard asset.isExportable else {
            completion(VideoTrimmerError.sourceNotExportable)
            return
        }

        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID())
        else {
            assertionFailure("Unable to add video track to composition \(composition).")
            return
        }

        guard let videoAssetTrack: AVAssetTrack = asset.tracks(withMediaType: .video).first else {
            assertionFailure("Unable to obtain video track from asset \(asset).")
            return
        }

        let startTime = CMTime(seconds: Double(clip.startTime), preferredTimescale: timeScale)
        let endTime = CMTime(seconds: Double(clip.stopTime), preferredTimescale: timeScale)

        let durationOfCurrentSlice = CMTimeSubtract(endTime, startTime)
        let timeRangeForCurrentSlice = CMTimeRangeMake(start: startTime, duration: durationOfCurrentSlice)

        do {
            try videoTrack.insertTimeRange(timeRangeForCurrentSlice, of: videoAssetTrack, at: CMTime())
        } catch {
            completion(error)
        }

        guard
            let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
        else { return }

        exportSession.outputURL = URL(fileURLWithPath: clip.path)
        exportSession.outputFileType = fileType
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            completion(exportSession.error)
        }
    }
}
