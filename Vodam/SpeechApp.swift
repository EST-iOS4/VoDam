import SwiftUI
import ComposableArchitecture
// TCA 개념 제대로 짚고,
// TCA는 결국 단방향 데이터 흐름을 만드는 것이 목표인데,
// 가->나->다->라->가 >>한쪽으로만 흐르는
// 3가지 핵심 원리
// 첫번째, 1. 한곳에서 다 관리를 하자.
// 빵을 만드는 공장에서 일을하는데, 누구는 단팥빵, 누구는 피자빵을 통일 되지않기떄문에, 한명(한곳) 단팥빵을 만들든, 피자빵을믄단, 한곳에 다 관리를하자.
// 두번쨰는 2. 하나의 뷰에서, 하나의 기능만 대응하자
// 내가 단팥빵을 만드는 공장에서 일을하는데, 옆에서 피자빵공장에서 피 아무상관없다는거조.
// 세번쨰는, 한곳에는 (사장) -> 단팥빵 만다는 공장만 가서 일을해 출입할수있는 key를 주는거죠,


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
