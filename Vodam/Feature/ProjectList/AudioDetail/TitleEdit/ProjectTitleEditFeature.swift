//
//  ProjectTitleEditFeature.swift
//  Vodam
//
//  Created by 서정원 on 12/7/25.
//

import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct ProjectTitleEditFeature {
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    
    @ObservableState
    struct State: Equatable, Identifiable {
        var project: Project
        var editedName: String
        var currentUser: User?
        var isSaving = false
        @Presents var alert: AlertState<Action.Alert>?
        
        var id: UUID { project.id }
        
        init(project: Project, currentUser: User?) {
            self.project = project
            self.currentUser = currentUser
            self.editedName = project.name
        }
        
        var trimmedName: String {
            editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var canConfirm: Bool {
            !trimmedName.isEmpty && trimmedName != project.name
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case confirmButtonTapped(ModelContext)
        case saveResponse(Result<Project, Error>)
        case alert(PresentationAction<Alert>)
        case delegate(DelegateAction)
        
        enum Alert: Equatable {}
        enum DelegateAction: Equatable {
            case didFinish(Project)
        }
    }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .confirmButtonTapped(let context):
                let newName = state.trimmedName
                guard !newName.isEmpty else {
                    state.alert = AlertState {
                        TextState("프로젝트 이름을 입력해주세요")
                    }
                    return .none
                }
                
                state.isSaving = true
                let project = state.project
                let ownerId = state.currentUser?.ownerId
                
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        try await MainActor.run {
                            try projectLocalDataClient.update(
                                context,
                                project.id.uuidString,
                                newName,
                                nil,
                                nil,
                                nil
                            )
                        }
                        
                        var updatedProject = project
                        updatedProject.name = newName
                        
                        if let ownerId {
                            let payload = await ProjectPayload(
                                id: updatedProject.id.uuidString,
                                name: updatedProject.name,
                                creationDate: updatedProject.creationDate,
                                category: updatedProject.category,
                                isFavorite: updatedProject.isFavorite,
                                filePath: updatedProject.filePath,
                                fileLength: updatedProject.fileLength,
                                transcript: updatedProject.transcript,
                                ownerId: ownerId,
                                syncStatus: updatedProject.syncStatus
                            )
                            try await firebaseClient.updateProject(ownerId, payload)
                        }
                        await send(.saveResponse(.success(updatedProject)))
                    } catch {
                        await send(.saveResponse(.failure(error)))
                    }
                }
                
            case .saveResponse(.success(let updatedProject)):
                state.isSaving = false
                state.project = updatedProject
                state.editedName = updatedProject.name
                return .send(.delegate(.didFinish(updatedProject)))
                
            case .saveResponse(.failure):
                state.isSaving = false
                state.alert = AlertState {
                    TextState("제목을 수정하지 못했습니다. 다시 시도해주세요")
                }
                return .none
                
            case .alert(.dismiss):
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}
