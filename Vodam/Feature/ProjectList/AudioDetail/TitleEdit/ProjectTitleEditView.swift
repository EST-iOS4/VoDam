//
//  ProjectTitleEditView.swift
//  Vodam
//
//  Created by 서정원 on 11/30/25.
//

import ComposableArchitecture
import SwiftData
import SwiftUI

struct ProjectTitleEditView: View {
    @Bindable var store: StoreOf<ProjectTitleEditFeature>
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Section("프로젝트 이름") {
                TextField("새로운 이름", text: $store.editedName)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
        }
        .disabled(store.isSaving)
        .navigationTitle("제목 수정")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("확인") {
                    store.send(.confirmButtonTapped(context))
                }
                .disabled(!store.canConfirm || store.isSaving)
            }
        }
        .overlay(alignment: .center) {
            if store.isSaving {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
