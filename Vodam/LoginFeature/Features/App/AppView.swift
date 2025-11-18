//
//  AppView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    // 모든 곳에서 일아는 상태나 리듀서를 갖고있어요)
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack{
                MainView(
                    //키를 통해서
                   store: store.scope(state: \.main, action: \.main)
                )
            }
    }
}

