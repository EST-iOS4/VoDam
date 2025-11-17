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
            NavigationStack {
                VStack {
                    Spacer()
                    
                    Text("여기에 메인 UI 들어갈 예정")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .navigationTitle("새 프로젝트 생성")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button{
                            // TODO: 나중에 프로필 플로우 열기
                            print("프로필 버튼 탭")
                        } label: {
                            Image(systemName: "person.circle")
                                .imageScale(.large)
                        }
                    }
                }
            }
        }
    }
}
