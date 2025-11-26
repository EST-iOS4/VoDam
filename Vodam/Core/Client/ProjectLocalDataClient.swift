//
//  RecordingLocalDataClient.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Dependencies
import Foundation
import SwiftData

struct ProjectLocalDataClient {
    var save:
        @Sendable (
            _ context: ModelContext,
            _ name: String,
            _ category: ProjectCategory,
            _ filePath: String?,
            _ fileLength: Int?,
            _ transcript: String?,
            _ ownerId: String?
        ) throws -> ProjectPayload

    var fetchAll:
        @Sendable (
            _ context: ModelContext,
            _ ownerId: String?
        ) throws -> [ProjectPayload]

    var update:
        @Sendable (
            _ context: ModelContext,
            _ id: String,
            _ name: String?,
            _ isFavorite: Bool?,
            _ transcript: String?,
            _ syncStatus: SyncStatus?
        ) throws -> Void

    var delete:
        @Sendable (
            _ context: ModelContext,
            _ id: String
        ) throws -> Void

    var deleteAllForOwner:
        @Sendable (_ context: ModelContext, _ ownerId: String) throws -> Void

    var migrateGuestProjects:
        @Sendable (
            _ context: ModelContext,
            _ newOwnerId: String
        ) throws -> [ProjectPayload]

    var updateSyncStatus:
        @Sendable (
            _ context: ModelContext,
            _ ids: [String],
            _ status: SyncStatus,
            _ ownerId: String
        ) throws -> Void
}

extension ProjectLocalDataClient: DependencyKey {
    static var liveValue: ProjectLocalDataClient {
        .init(
            save: {
                context,
                name,
                category,
                filePath,
                fileLength,
                transcript,
                ownerId in
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

                print(
                    "[ProjectLocalDataClient] 저장 성공 → \(name), category: \(category.rawValue), ownerId: \(ownerId ?? "nil")"
                )

                return ProjectPayload(model: model)
            },

            fetchAll: { context, ownerId in
                let descriptor: FetchDescriptor<ProjectModel>

                if let ownerId {
                    // 로그인 사용자: 해당 ownerId의 프로젝트 + 게스트 프로젝트(아직 마이그레이션 안된 것)
                    descriptor = FetchDescriptor<ProjectModel>(
                        predicate: #Predicate { project in
                            project.ownerId == ownerId || project.ownerId == nil
                        },
                        sortBy: [
                            SortDescriptor(\.creationDate, order: .reverse)
                        ]
                    )
                } else {
                    // 비회원: ownerId가 nil인 프로젝트만
                    descriptor = FetchDescriptor<ProjectModel>(
                        predicate: #Predicate { project in
                            project.ownerId == nil
                        },
                        sortBy: [
                            SortDescriptor(\.creationDate, order: .reverse)
                        ]
                    )
                }

                let models = try context.fetch(descriptor)
                print(
                    "[ProjectLocalDataClient] fetchAll → \(models.count)개 조회 (ownerId: \(ownerId ?? "nil"))"
                )

                return models.map(ProjectPayload.init(model:))
            },

            update: { context, id, name, isFavorite, transcript, syncStatus in
                let descriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        project.id == id
                    }
                )

                guard let model = try context.fetch(descriptor).first else {
                    print(
                        "[ProjectLocalDataClient] update 실패 - id: \(id) 찾을 수 없음"
                    )
                    return
                }

                if let name { model.name = name }
                if let isFavorite { model.isFavorite = isFavorite }
                if let transcript { model.transcript = transcript }
                if let syncStatus { model.syncStatus = syncStatus }

                try context.save()
                print("[ProjectLocalDataClient] update 성공 → id: \(id)")
            },

            delete: { context, id in
                let descriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        project.id == id
                    }
                )

                guard let model = try context.fetch(descriptor).first else {
                    print(
                        "[ProjectLocalDataClient] delete 실패 - id: \(id) 찾을 수 없음"
                    )
                    return
                }

                context.delete(model)
                try context.save()
                print("[ProjectLocalDataClient] delete 성공 → id: \(id)")
            },

            deleteAllForOwner: { context, ownerId in
                let descriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        project.ownerId == ownerId
                    }
                )

                let models = try context.fetch(descriptor)

                guard !models.isEmpty else {
                    print(
                        "[ProjectLocalDataClient] 삭제 대상 없음 (ownerId: \(ownerId))"
                    )
                    return
                }

                for models in models {
                    context.delete(models)
                }

                try context.save()
                print(
                    "[ProjectLocalDataClient] \(models.count)개 프로젝트 삭제 완료 (ownerId: \(ownerId))"
                )
            },

            migrateGuestProjects: { context, newOwnerId in
                let descriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        project.ownerId == nil
                            && project.syncStatusRaw == "localOnly"
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
                print(
                    "[ProjectLocalDataClient] \(guestProjects.count)개 게스트 프로젝트 마이그레이션 완료 → ownerId: \(newOwnerId)"
                )

                return guestProjects.map(ProjectPayload.init(model:))
            },

            updateSyncStatus: { context, ids, status, ownerId in
                let descriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        ids.contains(project.id)
                    }
                )

                let models = try context.fetch(descriptor)

                for model in models {
                    model.syncStatus = status
                    model.ownerId = ownerId
                }

                try context.save()
                print(
                    "[ProjectLocalDataClient] \(models.count)개 syncStatus 업데이트 → \(status.rawValue)"
                )
            }
        )
    }

    static var testValue: ProjectLocalDataClient {
        .init(
            save: { _, name, category, _, _, _, _ in
                return ProjectPayload(
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
            fetchAll: { _, _ in [] },
            update: { _, _, _, _, _, _ in },
            delete: { _, _ in },
            deleteAllForOwner: { _, _ in },
            migrateGuestProjects: { _, _ in [] },
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
