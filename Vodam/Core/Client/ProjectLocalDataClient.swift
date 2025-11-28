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
            _ ownerId: String,
            _ remoteAudioPath: String?
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
                
                //저장 직후 바로 조회해서 확인
                let modelId = model.id
                let verifyDescriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        project.id == modelId
                    }
                )
                if let verified = try? context.fetch(verifyDescriptor).first {
                    print("저장 직후 조회 성공 - id: \(verified.id), ownerId: \(verified.ownerId ?? "nil"), syncStatus: \(verified.syncStatusRaw)")
                } else {
                    print("저장 직후 조회 실패 - 저장이 안되었을 수 있음!")
                }

                return ProjectPayload(model: model)
            },

            fetchAll: { context, ownerId in
                let descriptor: FetchDescriptor<ProjectModel>

                if let ownerId {
                    // 로그인 사용자: 해당 ownerId의 프로젝트 + 게스트 프로젝트(아직 마이그레이션 안된 것)
                    print("fetchAll 조건: ownerId == \(ownerId) OR ownerId == nil")
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
                    print("fetchAll 조건: ownerId == nil (비회원)")
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
                
                // 조회된 모든 프로젝트 출력
                for (index, model) in models.enumerated() {
                    print("  [\(index)] id: \(model.id), name: \(model.name), ownerId: \(model.ownerId ?? "nil"), syncStatus: \(model.syncStatusRaw)")
                }

                return models.map(ProjectPayload.init(model:))
            },

            update: { context, id, name, isFavorite, transcript, syncStatus in
                let targetId = id
                let descriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        project.id == targetId
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
                let targetId = id
                let descriptor = FetchDescriptor<ProjectModel>(
                    predicate: #Predicate { project in
                        project.id == targetId
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
                           print(
                               "[ProjectLocalDataClient] \(guestProjects.count)개 게스트 프로젝트 마이그레이션 완료 → ownerId: \(newOwnerId)"
                           )

                           return guestProjects.map(ProjectPayload.init(model:))
                       },


            updateSyncStatus: { context, ids, status, ownerId, remoteAudioPath in
                print("updateSyncStatus 호출됨 - ids: \(ids), ownerId: \(ownerId)")
                
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
                
                print("updateSyncStatus 조회 결과 - \(models.count)개 찾음")
                for model in models {
                    print("  - id: \(model.id), ownerId: \(model.ownerId ?? "nil"), syncStatus: \(model.syncStatusRaw)")
                }

                for model in models {
                    model.syncStatus = status
                    model.ownerId = ownerId
                    if let remoteAudioPath {
                        model.remoteAudioPath = remoteAudioPath
                    }
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
            updateSyncStatus: { _, _, _, _, _ in }
        )
    }
}
extension DependencyValues {
    var projectLocalDataClient: ProjectLocalDataClient {
        get { self[ProjectLocalDataClient.self] }
        set { self[ProjectLocalDataClient.self] = newValue }
    }
}
