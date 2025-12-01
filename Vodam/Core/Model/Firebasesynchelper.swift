//
//  Firebasesynchelper.swift
//  Vodam
//
//  Created by 송영민 on 11/28/25.
//

import SwiftData
import Foundation

struct FirebaseSyncHelper {
    
    static func handleUserChange(
        oldValue: User?,
        newValue: User?,
        modelContext: ModelContext,
        projectLocalDataClient: ProjectLocalDataClient,
        firebaseClient: FirebaseClient,
        fileCloudClient: FileCloudClient,
        onComplete: @escaping () -> Void
    ) {
        guard let user = newValue else { return }
        
        guard oldValue == nil || oldValue?.ownerId != newValue?.ownerId else {
            return
        }
        
        let ownerId = user.ownerId
        
        Task {
            do {
                let migratedProjects = await MainActor.run {
                    do {
                        return try projectLocalDataClient.migrateGuestProjects(
                            modelContext,
                            ownerId
                        )
                    } catch {
                        print("마이그레이션 실패: \(error)")
                        return []
                    }
                }
                
                if migratedProjects.isEmpty {
                    print("마이그레이션 대상 게스트 프로젝트 없음")
                } else {
                    print("게스트 프로젝트 \(migratedProjects.count)개 마이그레이션 시작")
                    
                    var syncedPayloads: [ProjectPayload] = []
                    
                    for payload in migratedProjects {
                        var remotePath: String? = nil
                        
                        if let filePath = payload.filePath,
                           (payload.category == .audio || payload.category == .file || payload.category == .pdf) {
                            
                            do {
                                let localURL = URL(fileURLWithPath: filePath)
                                remotePath = try await fileCloudClient.uploadFile(
                                    ownerId,
                                    payload.id,
                                    localURL
                                )
                                print("  Storage 업로드 성공: \(payload.name) → \(remotePath ?? "")")
                            } catch {
                                print("  Storage 업로드 실패: \(payload.name) - \(error)")
                            }
                        }
                        
                        let syncedPayload = ProjectPayload(
                            id: payload.id,
                            name: payload.name,
                            creationDate: payload.creationDate,
                            category: payload.category,
                            isFavorite: payload.isFavorite,
                            filePath: payload.filePath,
                            fileLength: payload.fileLength,
                            transcript: payload.transcript,
                            ownerId: ownerId,
                            syncStatus: .synced,
                            remoteAudioPath: remotePath
                        )
                        syncedPayloads.append(syncedPayload)
                    }
                    
                    try await firebaseClient.uploadProjects(ownerId, syncedPayloads)
                    print("Firestore 업로드 완료: \(syncedPayloads.count)개")
                    
                    await MainActor.run {
                        for syncedPayload in syncedPayloads {
                            do {
                                try projectLocalDataClient.updateSyncStatus(
                                    modelContext,
                                    [syncedPayload.id],
                                    .synced,
                                    ownerId,
                                    syncedPayload.remoteAudioPath
                                )
                            } catch {
                                print("updateSyncStatus 실패: \(error)")
                            }
                        }
                    }
                    print(
                        "게스트 프로젝트 \(migratedProjects.count)개 마이그레이션 및 Firebase 동기화 완료"
                    )
                }
                
                let remoteProjects = try await firebaseClient.fetchProjects(ownerId)
                print(
                    "Firebase에서 \(remoteProjects.count)개 프로젝트 가져옴 (ownerId: \(ownerId))"
                )
                
                await MainActor.run {
                    syncRemoteProjectsToLocal(
                        remoteProjects,
                        ownerId: ownerId,
                        modelContext: modelContext,
                        projectLocalDataClient: projectLocalDataClient,
                        fileCloudClient: fileCloudClient
                    )
                }
                
                // 동기화 완료 콜백
                await MainActor.run {
                    onComplete()
                }
                
            } catch {
                print("로그인 후 Firebase 동기화 실패: \(error)")
            }
        }
    }
    
    static func syncRemoteProjectsToLocal(
        _ remoteProjects: [ProjectPayload],
        ownerId: String,
        modelContext: ModelContext,
        projectLocalDataClient: ProjectLocalDataClient,
        fileCloudClient: FileCloudClient
    ) {
        do {
            let descriptor = FetchDescriptor<ProjectModel>(
                predicate: #Predicate { project in
                    project.ownerId == ownerId
                }
            )
            
            let existingModels = try modelContext.fetch(descriptor)
            var existingById = Dictionary(
                uniqueKeysWithValues: existingModels.map { ($0.id, $0) }
            )
            
            for payload in remoteProjects {
                let model: ProjectModel
                if let existing = existingById[payload.id] {
                    model = existing
                    model.name = payload.name
                    model.creationDate = payload.creationDate
                    model.category = payload.category
                    model.isFavorite = payload.isFavorite
                    model.filePath = payload.filePath
                    model.fileLength = payload.fileLength
                    model.transcript = payload.transcript
                    model.syncStatus = .synced
                    model.remoteAudioPath = payload.remoteAudioPath
                } else {
                    model = ProjectModel(
                        id: payload.id,
                        name: payload.name,
                        creationDate: payload.creationDate,
                        category: payload.category,
                        isFavorite: payload.isFavorite,
                        filePath: payload.filePath,
                        fileLength: payload.fileLength,
                        transcript: payload.transcript,
                        ownerId: ownerId,
                        syncStatus: .synced,
                        remoteAudioPath: payload.remoteAudioPath
                    )
                    modelContext.insert(model)
                    existingById[payload.id] = model
                }
                
                if let remotePath = payload.remoteAudioPath,
                   (payload.category == .audio || payload.category == .file || payload.category == .pdf) {
                    let currentLocalPath = model.filePath
                    
                    Task {
                        do {
                            let newLocalPath = try await fileCloudClient.downloadFileIfNeeded(
                                ownerId,
                                payload.id,
                                remotePath,
                                currentLocalPath
                            )
                            
                            await MainActor.run {
                                model.filePath = newLocalPath
                                model.remoteAudioPath = remotePath
                                model.syncStatus = .synced
                                try? modelContext.save()
                            }
                            
                            print("파일 다운로드 완료: \(payload.name)")
                        } catch {
                            print("파일 다운로드 실패: \(payload.name) - \(error)")
                        }
                    }
                }
            }
            
            try modelContext.save()
            print("[FirebaseSyncHelper] Firebase + Storage → SwiftData 동기화 완료: \(remoteProjects.count)개 upsert")
        } catch {
            print("[FirebaseSyncHelper] syncRemoteProjectsToLocal 실패: \(error)")
        }
    }
}
