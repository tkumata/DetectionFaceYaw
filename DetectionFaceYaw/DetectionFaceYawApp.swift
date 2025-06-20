import SwiftUI

@main
struct FaceYawDetectionApp: App {
    @AppStorage("skipNotice") var skipNotice: Bool = false

    var body: some Scene {
        WindowGroup {
            if skipNotice {
                FaceDetectionView()
            } else {
                LaunchNoticeView()
            }
        }
    }
}
