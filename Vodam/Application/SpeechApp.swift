import ComposableArchitecture
import GoogleSignIn
import KakaoSDKAuth
import KakaoSDKCommon
import SwiftData
import SwiftUI
import FirebaseCore

@main
struct VodamApp: App {
    
    let modelContainer: ModelContainer
    let store: StoreOf<AppFeature>
    
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
        
        do {
            modelContainer = try ModelContainer(for: ProjectModel.self)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
        
        SwiftDataClient.configure(container: modelContainer)
        
        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
        
        print("SwiftDataClient 싱글톤 초기화 완료")
        print("ProjectLocalDataClient 초기화 완료")
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .environment(\.font, AppFont.pretendardRegular(size: 16))
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                        return
                    }
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
