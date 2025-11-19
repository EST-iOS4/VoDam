import KakaoSDKCommon
import KakaoSDKAuth
import SwiftUI
import ComposableArchitecture

@main
struct VodamApp: App {
    
    init() {
        KakaoSDK.initSDK(appKey: "30d61918bb608e9d6159398187eaf421")
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(
                    initialState: AppFeature.State(),
                    reducer: {
                        AppFeature()
                    }
                )
            )
            
            .onOpenURL{ url in
                if AuthApi.isKakaoTalkLoginUrl(url) {
                    _ = AuthController.handleOpenUrl(url: url)
                }
            }
        }
    }
}
