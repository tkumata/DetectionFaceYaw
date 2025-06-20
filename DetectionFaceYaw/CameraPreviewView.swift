import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = PreviewHostingView()
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }

    class PreviewHostingView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.first?.frame = bounds
        }
    }
}
