import Foundation
import AVFoundation
import Vision
import SwiftUI
import UIKit

enum DetectionState: String {
    case safe = "SAFE"
    case caution = "CAUTION"
    case danger = "DANGER"
    case unidentified = "UNIDENTIFIED"

    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .yellow
        case .danger: return .red
        case .unidentified: return .gray
        }
    }
}

struct DetectedPerson: Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    let riskScore: Double
    let state: DetectionState
    let hasFace: Bool
}

class FaceDetectionProcessor: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var detectedPeople: [DetectedPerson] = []
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
    
    // Vision リクエストをプロパティとして保持（再利用によるパフォーマンス向上）
    private let humanRequest = VNDetectHumanRectanglesRequest()
    private let faceRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        return request
    }()

    // 定量的評価のための定数
    private let safeThreshold = 0.15
    private let cautionThreshold = 0.40

    func setupSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                return
            }
            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.queue)
            guard self.session.canAddOutput(output) else { return }
            self.session.addOutput(output)

            if let connection = output.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 90 // Portrait (Right side up)
                } else {
                    connection.videoOrientation = .portrait
                }
            }

            self.previewLayer.session = self.session
            self.previewLayer.videoGravity = .resizeAspectFill

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Vision リクエストの実行（再利用されたリクエストを使用）
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        
        do {
            try handler.perform([humanRequest, faceRequest])
            
            let humans = humanRequest.results ?? []
            let faces = faceRequest.results ?? []
            
            processResults(humans: humans, faces: faces)
        } catch {
            print("Vision error: \(error)")
        }
    }

    private func processResults(humans: [VNHumanObservation], faces: [VNFaceObservation]) {
        var results: [DetectedPerson] = []

        for human in humans {
            // 標準メソッドを使用して Vision の正規化座標をレイヤー座標に変換
            let humanBox = previewLayer.layerRectConverted(fromMetadataOutputRect: human.boundingBox)
            
            // 人体領域に含まれる顔を検索
            let containedFace = faces.first { face in
                let faceBox = previewLayer.layerRectConverted(fromMetadataOutputRect: face.boundingBox)
                return humanBox.intersects(faceBox)
            }

            let riskScore: Double
            let state: DetectionState
            let hasFace: Bool

            if let face = containedFace {
                // 数学的ロジック: FFI = cos(yaw) * cos(pitch)
                let yaw = face.yaw?.doubleValue ?? 0
                let pitch = face.pitch?.doubleValue ?? 0
                let confidence = Double(face.confidence)
                
                // 仕様書に基づき、FFIが負にならないようガード (max(0, ...))
                let ffi = max(0, cos(yaw) * cos(pitch))
                riskScore = 1.0 - (ffi * confidence)
                hasFace = true
            } else {
                // 顔が見えない場合は最大リスク
                riskScore = 1.0
                hasFace = false
            }

            // スコアに基づく状態判定
            if riskScore < safeThreshold {
                state = .safe
            } else if riskScore < cautionThreshold {
                state = .caution
            } else {
                state = .danger
            }

            results.append(DetectedPerson(
                boundingBox: humanBox,
                riskScore: riskScore,
                state: state,
                hasFace: hasFace
            ))
        }

        DispatchQueue.main.async {
            self.detectedPeople = results
        }
    }
}
