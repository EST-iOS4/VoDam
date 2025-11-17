//
//  AppView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>
    
    var body: some View {
        Text("AppView")
    }
}
