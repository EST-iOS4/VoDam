//
//  FirebaseClient.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Dependencies
import FirebaseFirestore
import FirebaseStorage
import Foundation

struct FirebaseClient {
    var deleteAllForUser: @Sendable (_ ownerId: String) async throws -> Void
    
    // MARK: - Project Functions
    var uploadProjects:
        @Sendable (_ ownerId: String, _ projects: [ProjectPayload])
            async throws -> Void
    
    var fetchProjects:
        @Sendable (_ ownerId: String) async throws -> [ProjectPayload]
    
    var updateProject:
        @Sendable (_ ownerId: String, _ project: ProjectPayload)
            async throws -> Void
    
    var deleteProject:
        @Sendable (_ ownerId: String, _ projectId: String)
            async throws -> Void
    
    var createChatRoom:
        @Sendable (_ projectName: String) async throws -> Void
    
    var listenToChatRooms:
    @Sendable () -> AsyncStream<[ChattingInfo]>
}

extension FirebaseClient: DependencyKey {
    static var liveValue: FirebaseClient {
        .init(
            deleteAllForUser: { ownerId in
               let db = Firestore.firestore()
             let userRef = db.collection("users").document(ownerId)
                
                // 1. projects에서 remoteAudioPath 가져오기
                let projectsRef = userRef.collection("projects")
                let projectsSnapshot = try await projectsRef.getDocuments()
                
                
                // 2. Storage 파일 삭제
                let storage = Storage.storage()
                for doc in projectsSnapshot.documents {
                    if let remotePath = doc.data()["remoteAudioPath"] as? String,
                       !remotePath.isEmpty {
                        do {
                            let fileRef = storage.reference(withPath: remotePath)
                            try await fileRef.delete()
                            print("[FirebaseClient] Storage 파일 삭제: \(remotePath)")
                        } catch {
                            print("[FirebaseClient] Storage 파일 삭제 실패 (계속 진행): \(remotePath) - \(error)")
                        }
                    }
                }
                
                // 3. Firestore 문서 삭제 (batch)
                let recordingsRef = userRef.collection("recordings")
                let recordingsSnapshot = try await recordingsRef.getDocuments()
                
                let batch = db.batch()

                for doc in recordingsSnapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                
                for doc in projectsSnapshot.documents {
                    batch.deleteDocument(doc.reference)
                }

                batch.deleteDocument(userRef)

                try await batch.commit()

                print("[FirebaseClient] deleteAllForUser 완료: ownerId=\(ownerId), recordings=\(recordingsSnapshot.documents.count)개, projects=\(projectsSnapshot.documents.count)개 삭제")
            },
            
            // MARK: - Project Functions Implementation
            uploadProjects: { ownerId, projects in
                let db = Firestore.firestore()
                let batch = db.batch()
                
                for project in projects {
                    let docRef = db
                        .collection("users")
                        .document(ownerId)
                        .collection("projects")
                        .document(project.id)
                    
                    let data = project.toFirestoreData()
                    
                    // ✅ 디버깅: 저장할 데이터 출력
                    print("📝 [FirebaseClient] Firestore 저장 데이터:")
                    print("   - id: \(project.id)")
                    print("   - name: \(project.name)")
                    print("   - remoteAudioPath: \(data["remoteAudioPath"] ?? "nil")")
                    
                    await batch.setData(data, forDocument: docRef)
                }
                
                try await batch.commit()
                print("[FirebaseClient] projects 업로드 완료: ownerId=\(ownerId), count=\(projects.count)")
            },
            
            fetchProjects: { ownerId in
                let db = Firestore.firestore()
                let snapshot = try await db
                    .collection("users")
                    .document(ownerId)
                    .collection("projects")
                    .order(by: "creationDate", descending: true)
                    .getDocuments()
                
                let projects = snapshot.documents.compactMap { doc -> ProjectPayload? in
                    let data = doc.data()
                    
                    // ✅ 디버깅: Firestore에서 읽은 데이터 출력
                    print("📖 [FirebaseClient] Firestore 읽기:")
                    print("   - id: \(doc.documentID)")
                    print("   - remoteAudioPath: \(data["remoteAudioPath"] ?? "nil")")
                    
                    return ProjectPayload.fromFirestoreData(data)
                }
                
                print("[FirebaseClient] fetchProjects 완료: ownerId=\(ownerId), count=\(projects.count)")
                return projects
            },
            
            updateProject: { ownerId, project in
                let db = Firestore.firestore()
                let data = project.toFirestoreData()
                
                print("📝 [FirebaseClient] updateProject:")
                print("   - id: \(project.id)")
                print("   - remoteAudioPath: \(data["remoteAudioPath"] ?? "nil")")
                
                try await db
                    .collection("users")
                    .document(ownerId)
                    .collection("projects")
                    .document(project.id)
                    .setData(data, merge: true)
                
                print("[FirebaseClient] project 업데이트 완료: ownerId=\(ownerId), id=\(project.id)")
            },
            
            deleteProject: { ownerId, projectId in
                let db = Firestore.firestore()
                try await db
                    .collection("users")
                    .document(ownerId)
                    .collection("projects")
                    .document(projectId)
                    .delete()
                
                print("[FirebaseClient] project 삭제 완료: ownerId=\(ownerId), id=\(projectId)")
            },
            
            createChatRoom: { projectName in
                let db = Firestore.firestore()
                
                let [String:Any] = [
                    "title" : projectName,
                    "content" : "목록에 보여질 초기 메세지 -> 다른내용으로 변경 예정"
                    "recentEditedDate" : FieldValue.serverTimestamp()
                ]
                
                try await db
                    .collection("chatRooms")
                    .document(projectName)
                    .setData(data, merge: true) // 기존 데이터 유지
            },
            
            listenToChatRooms: {
                AsyncStream { continuation in
                    let db = Firebase.firestore()
                    
                    let listener = db.collection("chatRooms")
                        .order(by:"recentEditedDate", descending: true)
                        .addSnapshotListener{ snapshot, error in
                            
                            if let error = error {
                                print("⛔️ [FirebaseClient] 채팅목록 리스너에러 : \(error)")
                                continuation.finish()
                                return
                            }
                        // 문서가 없으면 빈 배열
                            guard let documents = snapshot?.documents else {
                                continuation.yield([])
                                return
                            }
                        // firestore -> chattinginfo
                            let rooms = documents.compactMap { doc -> ChattingInfo? in
                                let data = doc.data()
                                
                                let timestamp = data["recentEditedDate"] as! Timestamp
                                let date = timestamp?.dateValue() ?? Date()
                                
                                return ChattingInfo(
                                    id: doc.documentID,
                                    title: data["title"] as? String ?? doc.documentID,
                                    content: data["content"] as? String ?? "",
                                    recentEditedData: date
                                )
                            }
                            
                            continuation.yield(rooms)
                        }
                    
                    continuation.onTermination = { _ in
                        listener.remove()
                        print("[FirebaseClient] 채팅목록 리스너 해제")
                    }
                }
            }
        )
    }

    static var testValue: FirebaseClient {
        .init(
            deleteAllForUser: { _ in },
            uploadProjects: { _, _ in },
            fetchProjects: { _ in [] },
            updateProject: { _, _ in },
            deleteProject: { _, _ in }
        )
    }
}

extension DependencyValues {
    var firebaseClient: FirebaseClient {
        get { self[FirebaseClient.self] }
        set { self[FirebaseClient.self] = newValue }
    }
}

// MARK: - ProjectPayload Firestore Extension
extension ProjectPayload {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "name": name,
            "creationDate": Timestamp(date: creationDate),
            "category": category.rawValue,
            "isFavorite": isFavorite,
            "syncStatus": syncStatus.rawValue
        ]
        
        if let filePath { data["filePath"] = filePath }
        if let fileLength { data["fileLength"] = fileLength }
        if let transcript { data["transcript"] = transcript }
        if let ownerId { data["ownerId"] = ownerId }
        
        if let remoteAudioPath {
            data["remoteAudioPath"] = remoteAudioPath
            print("[ProjectPayload] remoteAudioPath 포함: \(remoteAudioPath)")
        } else {
            print("[ProjectPayload] remoteAudioPath가 nil입니다!")
        }
        
        if let summary {
                    data["summary"] = summary
                    print("✅ [ProjectPayload] summary 포함: \(summary.prefix(50))...")
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any]) -> ProjectPayload? {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let timestamp = data["creationDate"] as? Timestamp,
            let categoryRaw = data["category"] as? String,
            let category = ProjectCategory(rawValue: categoryRaw),
            let isFavorite = data["isFavorite"] as? Bool,
            let syncStatusRaw = data["syncStatus"] as? String,
            let syncStatus = SyncStatus(rawValue: syncStatusRaw)
        else {
            print("❌ [ProjectPayload] fromFirestoreData 실패 - 필수 필드 누락")
            return nil
        }
        
        let remoteAudioPath = data["remoteAudioPath"] as? String
        print("[ProjectPayload] remoteAudioPath 읽기: \(remoteAudioPath ?? "nil")")
        
        let summary = data["summary"] as? String
        if let summary = summary {
            print("📖 [ProjectPayload] summary 읽기: \(summary.prefix(50))...")
        } else {
            print("📖 [ProjectPayload] summary 없음")
        }
        
        return ProjectPayload(
            id: id,
            name: name,
            creationDate: timestamp.dateValue(),
            category: category,
            isFavorite: isFavorite,
            filePath: data["filePath"] as? String,
            fileLength: data["fileLength"] as? Int,
            transcript: data["transcript"] as? String,
            summary: summary,
            ownerId: data["ownerId"] as? String,
            syncStatus: syncStatus,
            remoteAudioPath: remoteAudioPath  // ✅ 읽기 추가
        )
    }
}
