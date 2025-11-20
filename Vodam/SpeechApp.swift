import SwiftUI
import ComposableArchitecture

@main
struct VodamApp: App {
    var body: some Scene {
        WindowGroup {
//            ContentView()
            
            AppView(
                store: Store(
                    initialState: AppFeature.State(),
                    reducer: {
                        AppFeature()
                    }
                )
            )
        }
    }
}
