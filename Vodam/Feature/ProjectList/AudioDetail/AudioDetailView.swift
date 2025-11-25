//
//  AudioDetailView.swift
//  Vodam
//
//  Created by 서정원 on 11/18/25.
//

import ComposableArchitecture
import SwiftUI

struct AudioDetailView: View {
    @Bindable var store: StoreOf<AudioDetailFeature>
    
    var body: some View {
        VStack {
            AudioDetailTabBar(selectedTab: $store.selectedTab)
            
            switch store.selectedTab {
            case .aiSummary:
                AISummaryView(
                    store: store.scope(
                        state: \.aiSummary, action: \.aiSummary
                    )
                )
            case .script:
                ScriptView(
                    store: store.scope(
                        state: \.script, action: \.script
                    )
                )
            }
            
            Spacer()
        }
        .navigationTitle(store.project.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AudioDetailView(
        store: Store(
            initialState:
                AudioDetailFeature.State(
                project:  Project(
                    id: UUID(), name: "10", creationDate: Calendar.current.date(
                        from: DateComponents(
                            year: 2025, month: 10, day: 16)
                    ) ?? Date(), category: .audio, isFavorite: false)
            )
        ) {
            AudioDetailFeature()
        }
    )
}
