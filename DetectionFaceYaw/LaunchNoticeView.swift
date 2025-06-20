//
//  LaunchNoticeView.swift
//  DetectionFaceYaw
//
//  Created by Tomokatsu Kumata on 2025/06/20.
//

import SwiftUI

struct LaunchNoticeView: View {
    @AppStorage("skipNotice") var skipNotice: Bool = false
    @State private var isChecked = false
    @State private var agreed = false

    var body: some View {
        VStack(spacing: 20) {
            Text("このアプリは顔の向きを検出します。「正面の顔」は緑色の枠で囲まれ、「正面以外の顔」は赤色の枠で囲まれます。\n本アプリでは映像はどこにも保存されません。\n赤枠＝うつ伏せとは限らないので最終的に目視で確認してください。")
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
