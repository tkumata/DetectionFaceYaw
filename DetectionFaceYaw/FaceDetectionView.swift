import SwiftUI
import AVFoundation

struct FaceDetectionView: View {
    @StateObject private var processor = FaceDetectionProcessor()

    var body: some View {
        ZStack {
            CameraPreviewView(previewLayer: processor.previewLayer)
                .ignoresSafeArea()

            ForEach(processor.detectedPeople) { person in
                ZStack(alignment: .topLeading) {
                    // 外枠
                    Rectangle()
                        .stroke(person.state.color, lineWidth: 3)
                        .frame(width: person.boundingBox.width, height: person.boundingBox.height)
                    
                    // ステータスラベル
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(person.state.rawValue)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .background(person.state.color)
                        
                        Text(String(format: "Risk: %.2f", person.riskScore))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .background(Color.black.opacity(0.6))
                        
                        if !person.hasFace {
                            Text("FACE HIDDEN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                                .background(Color.white)
                        }
                    }
                    .offset(y: -25)
                }
                .position(x: person.boundingBox.midX, y: person.boundingBox.midY)
            }
        }
        .onAppear {
            processor.setupSession()
        }
    }
}
