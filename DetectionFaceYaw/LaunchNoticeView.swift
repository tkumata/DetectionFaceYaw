import SwiftUI

struct LaunchNoticeView: View {
    @AppStorage("skipNotice") var skipNotice: Bool = false
    @State private var isChecked = false
    @State private var agreed = false

    var body: some View {
        VStack(spacing: 20) {
            Text("⚠️ 本アプリは、iPhone / iPad のカメラを利用して、人の顔が正面か、それ以外かを検知します。\n⚠️ そのため、うつ伏せかどうかを正確に確認できるわけではありませんのでご注意ください。\n⚠️ 顔認識の精度は Vision フレームワークに依存するため、使用環境や光の状況によって変動する可能性があります。")
                .padding()

            Text("ℹ️ 顔が正面の場合は、緑色の枠で、それ以外の場合は赤色の枠が顔部分を囲みます。\nℹ️ 本アプリは、ファインダに映るものをどこにも保存しません。\nℹ️ 緑色の枠だから安心とは限らないので最終的にご確認ください。")
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
        }
        .fullScreenCover(isPresented: $agreed) {
            FaceDetectionView()
        }
    }
}
