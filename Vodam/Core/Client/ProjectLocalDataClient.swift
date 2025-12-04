//
//  ProjectLocalDataClient.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Dependencies
import Foundation
import SwiftData

struct ProjectLocalDataClient: Sendable {
    
    var save: @Sendable (
        _ name: String,
        _ category: ProjectCategory,
        _ filePath: String?,
        _ fileLength: Int?,
        _ transcript: String?,
        _ ownerId: String?
    ) async throws -> ProjectPayload
    
    var fetchAll: @Sendable (
        _ ownerId: String?
    ) async throws -> [ProjectPayload]
    
    var update: @Sendable (
        _ id: String,
        _ name: String?,
        _ isFavorite: Bool?,
        _ transcript: String?,
        _ syncStatus: SyncStatus?,
        _ summary: String?
    ) async throws -> Void
    
    var delete: @Sendable (
        _ id: String
    ) async throws -> Void
    
    var deleteAllForOwner: @Sendable (
        _ ownerId: String
    ) async throws -> Void
    
    var insert: @Sendable (
        _ payload: ProjectPayload
    ) async throws -> Void
    
    var migrateGuestProjects: @Sendable (
        _ newOwnerId: String
    ) async throws -> [ProjectPayload]
    
    var updateSyncStatus: @Sendable (
        _ ids: [String],
        _ status: SyncStatus,
        _ ownerId: String,
        _ remoteAudioPath: String?
    ) async throws -> Void
}


extension ProjectLocalDataClient: DependencyKey {
    
    static func live(swiftDataClient: SwiftDataClient) -> ProjectLocalDataClient {
        ProjectLocalDataClient(
            save: { name, category, filePath, fileLength, transcript, ownerId in
                try await swiftDataClient.withContextReturning { context in
                    let model = ProjectModel(
                        name: name,
                        category: category,
                        filePath: filePath,
                        fileLength: fileLength,
                        transcript: transcript,
                        ownerId: ownerId,
                        syncStatus: .localOnly
                    )
                    
                    context.insert(model)
                    try context.save()
                    
                    print("[ProjectLocalDataClient] 저장 성공 → \(name), category: \(category.rawValue), ownerId: \(ownerId ?? "nil")")
                    
                    return ProjectPayload(model: model)
                }
            },
            
            fetchAll: { ownerId in
                try await swiftDataClient.withContextReturning { context in
                    let descriptor: FetchDescriptor<ProjectModel>
                    
                    if let ownerId {
                        descriptor = FetchDescriptor<ProjectModel>(
                            predicate: #Predicate { project in
                                project.ownerId == ownerId
                            },
                            sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
                        )
                    } else {
                        descriptor = FetchDescriptor<ProjectModel>(
                            predicate: #Predicate { project in
                                project.ownerId == nil
                            },
                            sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
                        )
                    }
                    
                    let models = try context.fetch(descriptor)
                    print("[ProjectLocalDataClient] fetchAll → \(models.count)개 조회 (ownerId: \(ownerId ?? "nil"))")
                    
                    return models.map(ProjectPayload.init(model:))
                }
            },
            
            update: { id, name, isFavorite, transcript, syncStatus, summary in
                try await swiftDataClient.withContext { context in
                    let targetId = id
                    let descriptor = FetchDescriptor<ProjectModel>(
                        predicate: #Predicate { project in
                            project.id == targetId
                        }
                    )
                    
                    guard let model = try context.fetch(descriptor).first else {
                        print("[ProjectLocalDataClient] update 실패 - id: \(id) 찾을 수 없음")
                        return
                    }
                    
                    if let name { model.name = name }
                    if let isFavorite { model.isFavorite = isFavorite }
                    if let transcript { model.transcript = transcript }
                    if let syncStatus { model.syncStatus = syncStatus }
                    if let summary { model.summary = summary }
                    
                    try context.save()
                    print("[ProjectLocalDataClient] update 성공 → id: \(id)")
                }
            },
            
            delete: { id in
                try await swiftDataClient.withContext { context in
                    let targetId = id
                    let descriptor = FetchDescriptor<ProjectModel>(
                        predicate: #Predicate { project in
                            project.id == targetId
                        }
                    )
                    
                    guard let model = try context.fetch(descriptor).first else {
                        print("[ProjectLocalDataClient] delete 실패 - id: \(id) 찾을 수 없음")
                        return
                    }
                    
                    context.delete(model)
                    try context.save()
                    print("[ProjectLocalDataClient] delete 성공 → id: \(id)")
                }
            },
            
            deleteAllForOwner: { ownerId in
                try await swiftDataClient.withContext { context in
                    let descriptor = FetchDescriptor<ProjectModel>(
                        predicate: #Predicate { project in
                            project.ownerId == ownerId
                        }
                    )
                    
                    let models = try context.fetch(descriptor)
                    
                    guard !models.isEmpty else {
                        print("[ProjectLocalDataClient] 삭제 대상 없음 (ownerId: \(ownerId))")
                        return
                    }
                    
                    for model in models {
                        context.delete(model)
                    }
                    
                    try context.save()
                    print("[ProjectLocalDataClient] \(models.count)개 프로젝트 삭제 완료 (ownerId: \(ownerId))")
                }
            },
            
            insert: { payload in
                try await swiftDataClient.withContext { context in
                    let model = ProjectModel(
                        id: payload.id,
                        name: payload.name,
                        creationDate: payload.creationDate,
                        category: payload.category,
                        isFavorite: payload.isFavorite,
                        filePath: payload.filePath,
                        fileLength: payload.fileLength,
                        transcript: payload.transcript,
                        summary: payload.summary,
                        ownerId: payload.ownerId,
                        syncStatus: payload.syncStatus,
                        remoteAudioPath: payload.remoteAudioPath
                    )
                    
                    context.insert(model)
                    try context.save()
                    print("[ProjectLocalDataClient] insert 성공 → id: \(payload.id)")
                }
            },
            
            migrateGuestProjects: { newOwnerId in
                try await swiftDataClient.withContextReturning { context in
                    let localOnlyRaw = SyncStatus.localOnly.rawValue
                    
                    let descriptor = FetchDescriptor<ProjectModel>(
                        predicate: #Predicate { project in
                            project.ownerId == nil
                            && project.syncStatusRaw == localOnlyRaw
                        }
                    )
                    
                    let guestProjects = try context.fetch(descriptor)
                    
                    guard !guestProjects.isEmpty else {
                        print("[ProjectLocalDataClient] 마이그레이션 대상 게스트 프로젝트 없음")
                        return []
                    }
                    
                    for project in guestProjects {
                        project.ownerId = newOwnerId
                    }
                    
                    try context.save()
                    print("[ProjectLocalDataClient] \(guestProjects.count)개 게스트 프로젝트 마이그레이션 완료")
                    
                    return guestProjects.map(ProjectPayload.init(model:))
                }
            },
            
            updateSyncStatus: { ids, status, ownerId, remoteAudioPath in
                try await swiftDataClient.withContext { context in
                    var models: [ProjectModel] = []
                    
                    for id in ids {
                        let targetId = id
                        let descriptor = FetchDescriptor<ProjectModel>(
                            predicate: #Predicate { project in
                                project.id == targetId
                            }
                        )
                        if let model = try context.fetch(descriptor).first {
                            models.append(model)
                        }
                    }
                    
                    for model in models {
                        model.syncStatus = status
                        model.ownerId = ownerId
                        if let remoteAudioPath {
                            model.remoteAudioPath = remoteAudioPath
                        }
                    }
                    
                    try context.save()
                    print("[ProjectLocalDataClient] \(models.count)개 syncStatus 업데이트 → \(status.rawValue)")
                }
            }
        )
    }
    
    static var liveValue: ProjectLocalDataClient {
        @Dependency(\.swiftDataClient) var swiftDataClient
        return live(swiftDataClient: swiftDataClient)
    }
    
    static var testValue: ProjectLocalDataClient {
        ProjectLocalDataClient(
            save: { name, category, _, _, _, _ in
                ProjectPayload(
                    id: UUID().uuidString,
                    name: name,
                    creationDate: .now,
                    category: category,
                    isFavorite: false,
                    filePath: nil,
                    fileLength: nil,
                    transcript: nil,
                    ownerId: nil,
                    syncStatus: .localOnly
                )
            },
            fetchAll: { _ in [] },
            update: { _, _, _, _, _, _ in },
            delete: { _ in },
            deleteAllForOwner: { _ in },
            insert: { _ in },
            migrateGuestProjects: { _ in [] },
            updateSyncStatus: { _, _, _, _ in }
        )
    }
}

extension DependencyValues {
    var projectLocalDataClient: ProjectLocalDataClient {
        get { self[ProjectLocalDataClient.self] }
        set { self[ProjectLocalDataClient.self] = newValue }
    }
}
