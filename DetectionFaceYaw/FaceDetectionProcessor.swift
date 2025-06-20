import Foundation
import AVFoundation
import Vision
import SwiftUI
import UIKit

struct DetectedFace: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGSize
    let isFacingFront: Bool
}

class FaceDetectionProcessor: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var faces: [DetectedFace] = []
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "videoQueue")
    @AppStorage("yawThreshold") private var yawThreshold: Double = 10.0

    func setupSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: self.queue)
            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addOutput(output)

            if let connection = output.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 0 // portrait
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

        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let observations = request.results as? [VNFaceObservation],
                  let layer = self?.previewLayer else { return }

            let size = layer.bounds.size
            var results: [DetectedFace] = []

            for face in observations {
                let yaw = face.yaw?.floatValue ?? 0
                let degrees = abs(Double(yaw * 180 / .pi))
                let isFront = degrees <= (self?.yawThreshold ?? 10.0)

                let boundingBox = face.boundingBox
                let width = boundingBox.width * size.width
                let height = boundingBox.height * size.height
                let x = boundingBox.origin.x * size.width
                let y = (1.0 - boundingBox.origin.y - boundingBox.height) * size.height
                let rect = CGRect(x: x, y: y, width: width, height: height)

                let faceData = DetectedFace(
                    position: CGPoint(x: rect.midX, y: rect.origin.y),
                    size: rect.size,
                    isFacingFront: isFront
                )
                results.append(faceData)
            }

            DispatchQueue.main.async {
                self?.faces = results
            }
        }

        // orientation は常に .right (縦向きで使用)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])
    }
}
