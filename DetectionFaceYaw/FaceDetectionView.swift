import SwiftUI
import AVFoundation

struct FaceDetectionView: View {
    @StateObject private var processor = FaceDetectionProcessor()

    var body: some View {
        ZStack {
            CameraPreviewView(previewLayer: processor.previewLayer)
                .ignoresSafeArea()

            ForEach(processor.faces) {
                face in Rectangle()
                    .stroke(face.isFacingFront ? Color.green : Color.red, lineWidth: 2)
                    .frame(width: face.size.width, height: face.size.height)
                    .position(face.position)
            }
        }
        .onAppear {
            processor.setupSession()
        }
    }
}
