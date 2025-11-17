import SwiftUI
import ComposableArchitecture

@main
struct VodamApp: App {
    var body: some Scene {
        WindowGroup {
//            ContentView()
            
            AppView(
                store: Store(
                    initialState: AppFeature.State(), // AppFeature의 상태를 Store에 전달
                    reducer: { // TCA는 클로저는 함수를 전달 받아야하므로 리듀서 클로저 생성
                        AppFeature() //Reduceer 객체
                    }
                )
            )
        }
    }
}
