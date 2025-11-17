//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import SwiftUI
import ComposableArchitecture

struct MainView: View {
    let store: StoreOf<MainFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { _ in
            Text("MainView")
                .font(.title)
        }
        
    }
}
