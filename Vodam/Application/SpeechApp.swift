import ComposableArchitecture
import GoogleSignIn
import KakaoSDKAuth
import KakaoSDKCommon
import SwiftData
import SwiftUI
import FirebaseCore

@main
struct VodamApp: App {
    
    init() {
        FirebaseApp.configure()
        
        guard
            let token = Bundle.main.object(
                forInfoDictionaryKey: "KAKAO_APP_KEY"
            ) as? String,
            !token.isEmpty
        else {
            fatalError(
                "KAKAO_APP_KEY이 Info.plist에 설정되지 않았습니다. Secrets.xcconfig의 TOKEN 값을 Info.plist에 추가해주세요."
            )
        }
        KakaoSDK.initSDK(appKey: token)
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
            
            .onOpenURL { url in
                if AuthApi.isKakaoTalkLoginUrl(url) {
                    _ = AuthController.handleOpenUrl(url: url)
                    return
                }
                _ = GIDSignIn.sharedInstance.handle(url)
            }
            
        }
        
        .modelContainer(for: ProjectModel.self)
    }
}
