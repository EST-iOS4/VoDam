//
//  AppView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//
import ComposableArchitecture
import SwiftUI


// MARK: View
struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack{
            MainView(
                store: store.scope(state: \.main, action: \.main)
            )
        }
    }
}
