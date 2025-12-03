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
    
    var upsertUserProfile: @Sendable (_ user: User) async throws -> User
    var fetchUserProfile: @Sendable (_ ownerId: String) async throws -> User?
    
    var uploadProjects:
    @Sendable (_ ownerId: String, _ projects: [ProjectPayload]) async throws -> Void
    
    var fetchProjects:
    @Sendable (_ ownerId: String) async throws -> [ProjectPayload]
    
    var updateProject:
    @Sendable (_ ownerId: String, _ project: ProjectPayload) async throws -> Void
    
    var deleteProject:
    @Sendable (_ ownerId: String, _ projectId: String) async throws -> Void
    
    var createChatRoom:
    @Sendable (_ ownerId: String, _ roomId: String, _ title: String) async throws -> Void
    
    var updateChatRoomPreview:
    @Sendable (_ ownerId: String, _ roomId: String, _ title: String, _ content: String) async throws -> Void
    
    var listenToChatRooms:
    @Sendable (_ ownerId: String) -> AsyncStream<[ChattingInfo]>
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
            
            upsertUserProfile: { user in
                let db = Firestore.firestore()
                let ref = db.collection("users").document(user.ownerId)
                
                let snapshot = try await ref.getDocument()
                var existing: [String: Any] = snapshot.data() ?? [:]
                
                if !user.name.isEmpty {
                    existing["name"] = user.name
                } else if existing["name"] == nil {
                    existing["name"] = "Apple User"
                }
                
                if let email = user.email, !email.isEmpty {
                    existing["email"] = email
                }
                
                existing["ownerId"] = user.ownerId
                existing["provider"] = user.provider.rawValue
                
                if let urlString = user.profileImageURL?.absoluteString {
                    existing["profileImageURL"] = urlString
                }
                
                existing["updatedAt"] = FieldValue.serverTimestamp()
                if snapshot.exists == false {
                    existing["createdAt"] = FieldValue.serverTimestamp()
                }
                
                try await ref.setData(existing, merge: true)
                
                let name = (existing["name"] as? String) ?? user.name
                let email = existing["email"] as? String ?? user.email
                let providerRaw = existing["provider"] as? String ?? user.provider.rawValue
                let provider = AuthProvider(rawValue: providerRaw) ?? user.provider
                
                let profileImageURLString = existing["profileImageURL"] as? String
                let profileImageURL = profileImageURLString.flatMap { URL(string: $0) }
                
                let finalUser = User(
                    id: user.id,
                    name: name,
                    email: email,
                    provider: provider,
                    profileImageURL: profileImageURL,
                    localProfileImageData: user.localProfileImageData
                )
                return finalUser
            },
            
            fetchUserProfile: { ownerId in
                let db = Firestore.firestore()
                let ref = db.collection("users").document(ownerId)
                let snapshot = try await ref.getDocument()
                
                guard let data = snapshot.data() else {
                    return nil
                }
                
                let name = data["name"] as? String ?? "Apple User"
                let email = data["email"] as? String
                
                let providerRaw = data["provider"] as? String ?? AuthProvider.apple.rawValue
                let provider = AuthProvider(rawValue: providerRaw) ?? .apple
                
                let profileImageURLString = data["profileImageURL"] as? String
                let profileImageURL = profileImageURLString.flatMap { URL(string: $0) }
                
                let components = ownerId.split(separator: ":", maxSplits: 1).map(String.init)
                let idPart: String
                if components.count == 2 {
                    idPart = components[1]
                } else {
                    idPart = ownerId
                }
                
                return User(
                    id: idPart,
                    name: name,
                    email: email,
                    provider: provider,
                    profileImageURL: profileImageURL,
                    localProfileImageData: nil
                )
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
                    
                    let data = await project.toFirestoreData()
                    
                    // ✅ 디버깅: 저장할 데이터 출력
                    print("📝 [FirebaseClient] Firestore 저장 데이터:")
                    print("   - id: \(project.id)")
                    print("   - name: \(project.name)")
                    print("   - remoteAudioPath: \(data["remoteAudioPath"] ?? "nil")")
                    
                    batch.setData(data, forDocument: docRef)
                }
                
                try await batch.commit()
                print("[FirebaseClient] projects 업로드 완료: ownerId=\(ownerId), count=\(projects.count)")
            },
            
            fetchProjects: { ownerId in
                //메세지 로드
                let db = Firestore.firestore()
                let snapshot = try await db
                    .collection("users")
                    .document(ownerId)
                    .collection("projects")
                    .order(by: "creationDate", descending: true)
                    .getDocuments()
                
                var projects: [ProjectPayload] = []
                for doc in snapshot.documents {
                    let data = doc.data()
                    
                    // ✅ 디버깅: Firestore에서 읽은 데이터 출력
                    print("📖 [FirebaseClient] Firestore 읽기:")
                    print("   - id: \(doc.documentID)")
                    print("   - remoteAudioPath: \(data["remoteAudioPath"] ?? "nil")")
                    
                    if let project = await ProjectPayload.fromFirestoreData(data) {
                        projects.append(project)
                    }
                }
                
                print("[FirebaseClient] fetchProjects 완료: ownerId=\(ownerId), count=\(projects.count)")
                return projects
            },
            
            updateProject: { ownerId, project in
                let db = Firestore.firestore()
                let data = await project.toFirestoreData()
                
                print("📝 [FirebaseClient] updateProject:")
                print("   - id: \(project.id)")
                print("   - remoteAudioPath: \(data["remoteAudioPath"] ?? "nil")")
                
                //메세지 저장
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
            
            createChatRoom: { ownerId, roomId, title in
                let db = Firestore.firestore()
                
                let data: [String: Any] = [
                    "title" : title,
                    "recentEditedDate" : FieldValue.serverTimestamp()
                ]
                
                try await db
                    .collection("users")
                    .document(ownerId)
                    .collection("chatRooms")
                    .document(roomId)
                    .setData(data, merge: true)
            },
            
            updateChatRoomPreview: { ownerId, roomId, title, content in
                let db = Firestore.firestore()
                
                let data: [String: Any] = [
                    "title" : title,
                    "content" : content,
                    "recentEditedDate" : FieldValue.serverTimestamp()
                ]
                
                try await db
                    .collection("users")
                    .document(ownerId)
                    .collection("chatRooms")
                    .document(roomId)
                    .setData(data, merge: true)
            },
            
            listenToChatRooms: { ownerId in
                AsyncStream { continuation in
                    let db = Firestore.firestore()
                    
                    let listener = db.collection("users")
                        .document(ownerId)
                        .collection("chatRooms")
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
                                
                                let timestamp = data["recentEditedDate"] as? Timestamp
                                let date = timestamp?.dateValue() ?? Date()
                                
                                return ChattingInfo(
                                    id: doc.documentID,
                                    title: data["title"] as? String ?? doc.documentID,
                                    content: data["content"] as? String ?? "",
                                    recentEditedDate: date
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
            upsertUserProfile: { user in user },
                    fetchUserProfile: { _ in nil },
            uploadProjects: { _, _ in },
            fetchProjects: { _ in [] },
            updateProject: { _, _ in },
            deleteProject: { _, _ in },
            createChatRoom: { _, _, _ in },
            updateChatRoomPreview: { _, _, _, _ in },
            listenToChatRooms: { _ in AsyncStream { continuation in continuation.finish() } }
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
    
    static func fromFirestoreData(_ data: [String: Any]) async -> ProjectPayload? {
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

