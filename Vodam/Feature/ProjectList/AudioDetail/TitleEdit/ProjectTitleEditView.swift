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
    
    var body: some View {
        Form {
            Section("프로젝트 이름") {
                HStack {
                    TextField("새로운 이름", text: $store.editedName)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    
                    if !store.editedName.isEmpty {
                        Button {
                            store.send(.clearButtonTapped)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .disabled(store.isSaving)
        .navigationTitle("제목 수정")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("확인") {
                    store.send(.confirmButtonTapped)
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
