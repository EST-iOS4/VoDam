//
//  Firebasesynchelper.swift
//  Vodam
//
//  Created by 송영민 on 11/28/25.
//

import Foundation

struct FirebaseSyncHelper {
    
    static func handleUserChange(
        oldValue: User?,
        newValue: User?,
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
                let migratedProjects = try await projectLocalDataClient.migrateGuestProjects(ownerId)
                
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
                    
                    for syncedPayload in syncedPayloads {
                        try await projectLocalDataClient.updateSyncStatus(
                            [syncedPayload.id],
                            .synced,
                            ownerId,
                            syncedPayload.remoteAudioPath
                        )
                    }
                    
                    print("게스트 프로젝트 \(migratedProjects.count)개 마이그레이션 및 Firebase 동기화 완료")
                }
                
                let remoteProjects = try await firebaseClient.fetchProjects(ownerId)
                print("Firebase에서 \(remoteProjects.count)개 프로젝트 가져옴 (ownerId: \(ownerId))")
                
                try await syncRemoteProjectsToLocal(
                    remoteProjects,
                    ownerId: ownerId,
                    projectLocalDataClient: projectLocalDataClient,
                    fileCloudClient: fileCloudClient
                )
                
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
        projectLocalDataClient: ProjectLocalDataClient,
        fileCloudClient: FileCloudClient
    ) async throws {
        let localProjects = try await projectLocalDataClient.fetchAll(ownerId)
        let localIds = Set(localProjects.map { $0.id })
        let remoteIds = Set(remoteProjects.map { $0.id })
        
        for remoteProject in remoteProjects {
            if localIds.contains(remoteProject.id) {
                try await projectLocalDataClient.update(
                    remoteProject.id,
                    remoteProject.name,
                    remoteProject.isFavorite,
                    remoteProject.transcript,
                    .synced,
                    remoteProject.summary
                )
            } else {
                try await projectLocalDataClient.insert(remoteProject)
            }
            
            if let remotePath = remoteProject.remoteAudioPath,
               (remoteProject.category == .audio || remoteProject.category == .file || remoteProject.category == .pdf) {
                
                let currentLocalPath = remoteProject.filePath
                
                do {
                    _ = try await fileCloudClient.downloadFileIfNeeded(
                        ownerId,
                        remoteProject.id,
                        remotePath,
                        currentLocalPath
                    )
                    
                    try await projectLocalDataClient.update(
                        remoteProject.id,
                        nil,
                        nil,
                        nil,
                        .synced,
                        nil
                    )
                    
                    print("파일 다운로드 완료: \(remoteProject.name)")
                } catch {
                    print("파일 다운로드 실패: \(remoteProject.name) - \(error)")
                }
            }
        }
        
        for localProject in localProjects {
            if !remoteIds.contains(localProject.id) && localProject.syncStatus == .synced {
                try await projectLocalDataClient.delete(localProject.id)
                print("원격에 없는 로컬 프로젝트 삭제: \(localProject.name)")
            }
        }
        
        print("[FirebaseSyncHelper] Firebase + Storage → SwiftData 동기화 완료: \(remoteProjects.count)개 upsert")
    }
}
