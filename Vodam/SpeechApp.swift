import SwiftUI
import ComposableArchitecture

@main
struct VodamApp: App {
    init(){
        // 커스텀 폰트 등록
        setupNavigationBarFont()
    }
    
    var body: some Scene {
        WindowGroup {
            //AppView : 첫화면, Root View
            AppView(
                store: Store(
                    initialState: AppFeature.State(),
                    reducer: {
                        // AppFeature: Reducer 인스턴스
                        AppFeature()
                    }
                )
            )
            // 전역 text Modifier
            .font(AppFont.pretendardRegular(size: 16))
        }
    }
    
    // MARK: - Navigation font Setup
    private func setupNavigationBarFont() {
#if os(iOS)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Large Title (큰 제목) - Bold 34pt
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "Pretendard-Bold", size: 34) ?? .systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        
        // Inline Title (작은 제목) - SemiBold 17pt
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Pretendard-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        
        // 배경색 투명
        appearance.configureWithTransparentBackground()
        
        // 적용
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
#endif
    }
    
}
