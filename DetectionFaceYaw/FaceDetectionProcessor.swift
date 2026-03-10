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
                    connection.videoRotationAngle = 0 // Portrait
                } else {
                    connection.videoOrientation = .portrait
                }
            }

            self.previewLayer.session = self.session
            self.previewLayer.videoGravity = .resizeAspectFill

            DispatchQueue.main.async {
                self.previewLayer.frame = UIScreen.main.bounds
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 1. 人体検出リクエスト (Revision 1 で十分)
        let humanRequest = VNDetectHumanRectanglesRequest()
        
        // 2. 顔検出リクエスト (Revision 3 で Pitch を取得)
        let faceRequest = VNDetectFaceLandmarksRequest()
        faceRequest.revision = VNDetectFaceLandmarksRequestRevision3

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
        let size = previewLayer.bounds.size
        var results: [DetectedPerson] = []

        // 検出された「人」ごとに評価を行う
        for human in humans {
            let humanBox = convertToLayerRect(human.boundingBox, size: size)
            
            // この人体領域に含まれる顔を探す
            let containedFace = faces.first { face in
                let faceBox = convertToLayerRect(face.boundingBox, size: size)
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
                
                let ffi = cos(yaw) * cos(pitch)
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

    private func convertToLayerRect(_ boundingBox: CGRect, size: CGSize) -> CGRect {
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height
        let x = boundingBox.origin.x * size.width
        let y = (1.0 - boundingBox.origin.y - boundingBox.height) * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
