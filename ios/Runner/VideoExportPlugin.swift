import Flutter
import ReplayKit
import AVFoundation
import Photos

class VideoExportPlugin: NSObject, FlutterPlugin {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var outputURL: URL?
    private var startTime: CMTime?
    private var pendingResult: FlutterResult?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.trimee.video_export",
            binaryMessenger: registrar.messenger()
        )
        let instance = VideoExportPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
        case "isAvailable":
            result(RPScreenRecorder.shared().isAvailable)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startRecording(result: @escaping FlutterResult) {
        guard RPScreenRecorder.shared().isAvailable else {
            result(FlutterError(code: "UNAVAILABLE", message: "Screen recording is not available", details: nil))
            return
        }

        guard !isRecording else {
            result(FlutterError(code: "ALREADY_RECORDING", message: "Already recording", details: nil))
            return
        }

        // 出力ファイルパス
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let fileName = "trimee_export_\(Int(Date().timeIntervalSince1970)).mp4"
        let url = URL(fileURLWithPath: documentsPath).appendingPathComponent(fileName)

        // 既存ファイル削除
        try? FileManager.default.removeItem(at: url)
        outputURL = url

        // AVAssetWriter設定
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            result(FlutterError(code: "WRITER_ERROR", message: "Failed to create asset writer: \(error)", details: nil))
            return
        }

        // 画面サイズ取得
        let screenScale = UIScreen.main.scale
        let screenBounds = UIScreen.main.bounds
        let videoWidth = Int(screenBounds.width * screenScale)
        let videoHeight = Int(screenBounds.height * screenScale)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight,
        ]

        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        assetWriter?.add(videoInput!)
        startTime = nil

        // ReplayKit キャプチャ開始
        RPScreenRecorder.shared().startCapture(handler: { [weak self] sampleBuffer, sampleBufferType, error in
            guard let self = self, error == nil else { return }

            if sampleBufferType == .video {
                self.processSampleBuffer(sampleBuffer)
            }
        }, completionHandler: { [weak self] error in
            if let error = error {
                result(FlutterError(code: "CAPTURE_ERROR", message: "Failed to start capture: \(error.localizedDescription)", details: nil))
            } else {
                self?.isRecording = true
                result(true)
            }
        })
    }

    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, let assetWriter = assetWriter, let videoInput = videoInput else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if startTime == nil {
            startTime = timestamp
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: timestamp)
        }

        if videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }

    private func stopRecording(result: @escaping FlutterResult) {
        guard isRecording else {
            result(FlutterError(code: "NOT_RECORDING", message: "Not currently recording", details: nil))
            return
        }

        isRecording = false
        pendingResult = result

        RPScreenRecorder.shared().stopCapture { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.pendingResult?(FlutterError(code: "STOP_ERROR", message: "Failed to stop capture: \(error.localizedDescription)", details: nil))
                    self.pendingResult = nil
                }
                return
            }

            self.videoInput?.markAsFinished()
            self.assetWriter?.finishWriting {
                guard let url = self.outputURL else {
                    DispatchQueue.main.async {
                        self.pendingResult?(FlutterError(code: "NO_OUTPUT", message: "No output URL", details: nil))
                        self.pendingResult = nil
                    }
                    return
                }

                // カメラロールに保存
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    guard status == .authorized || status == .limited else {
                        DispatchQueue.main.async {
                            self.pendingResult?(FlutterError(code: "PERMISSION_DENIED", message: "Photo library access denied", details: nil))
                            self.pendingResult = nil
                        }
                        return
                    }

                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    }) { success, error in
                        // 一時ファイル削除
                        try? FileManager.default.removeItem(at: url)

                        DispatchQueue.main.async {
                            if success {
                                self.pendingResult?(true)
                            } else {
                                self.pendingResult?(FlutterError(code: "SAVE_ERROR", message: "Failed to save: \(error?.localizedDescription ?? "unknown")", details: nil))
                            }
                            self.pendingResult = nil
                        }
                    }
                }
            }
        }
    }
}
