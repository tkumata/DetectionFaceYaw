import SwiftUI

struct LaunchNoticeView: View {
    @AppStorage("skipNotice") var skipNotice: Bool = false
    @State private var isChecked = false
    @State private var agreed = false

    var body: some View {
        VStack(spacing: 20) {
            Text("⚠️ 注意事項")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("• 本アプリは、AIによる人体検出と顔の3D姿勢推定を組み合わせて、うつ伏せ寝のリスクを数値化します。")
                Text("• あくまで補助ツールであり、医療機器ではありません。必ず目視での確認を併用してください。")
                Text("• 部屋の明るさや寝具の種類により、検出精度が変動する可能性があります。")
                Text("• 映像データは端末内で即時処理され、保存・送信されることはありません。")
            }
            .font(.subheadline)
            .padding()

            VStack(alignment: .leading, spacing: 10) {
                Text("ℹ️ 表示の意味")
                    .font(.headline)
                HStack {
                    Circle().fill(Color.green).frame(width: 15, height: 15)
                    Text("SAFE: 仰向け（安心）")
                }
                HStack {
                    Circle().fill(Color.yellow).frame(width: 15, height: 15)
                    Text("CAUTION: 傾き・横向き（注意）")
                }
                HStack {
                    Circle().fill(Color.red).frame(width: 15, height: 15)
                    Text("DANGER: うつ伏せ・顔隠れ（危険）")
                }
            }
            .font(.subheadline)
            .padding()

            Toggle("この画面を次回から表示しない", isOn: $isChecked)
                .padding()

            Button("同意してはじめる") {
                if isChecked {
                    skipNotice = true
                }
                agreed = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .fullScreenCover(isPresented: $agreed) {
            FaceDetectionView()
        }
    }
}
