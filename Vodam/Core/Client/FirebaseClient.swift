//
//  FirebaseClient.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Dependencies
import FirebaseFirestore
import Foundation

struct FirebaseClient {
//    var deleteAllForUser: @Sendable (_ ownerId: String) async throws -> Void
    
    // MARK: - Project Functions (신규)
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
}

extension FirebaseClient: DependencyKey {
    static var liveValue: FirebaseClient {
        .init(
//            deleteAllForUser: { ownerId in
//               let db = Firestore.firestore()
//             let userRef = db.collection("users").document(ownerId)
//                
//                // recordings 삭제
//                let recordingsRef = userRef.collection("recordings")
//                let recordingsSnapshot = try await recordingsRef.getDocuments()
//                
//                // projects 삭제
//                let projectsRef = userRef.collection("projects")
//                let projectsSnapshot = try await projectsRef.getDocuments()
//                
//                let batch = db.batch()
//
//                for doc in recordingsSnapshot.documents {
//                    batch.deleteDocument(doc.reference)
//                }
//                
//                for doc in projectsSnapshot.documents {
//                    batch.deleteDocument(doc.reference)
//                }
//
//                batch.deleteDocument(userRef)
//
//                try await batch.commit()
//
//                print("[FirebaseClient] deleteAllForUser 완료: ownerId=\(ownerId), recordings=\(recordingsSnapshot.documents.count)개, projects=\(projectsSnapshot.documents.count)개 삭제")
//            },
            
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
                    
                    batch.setData(
                        project.toFirestoreData(),
                        forDocument: docRef
                    )
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
                    return ProjectPayload.fromFirestoreData(data)
                }
                
                print("[FirebaseClient] fetchProjects 완료: ownerId=\(ownerId), count=\(projects.count)")
                return projects
            },
            
            updateProject: { ownerId, project in
                let db = Firestore.firestore()
                try await db
                    .collection("users")
                    .document(ownerId)
                    .collection("projects")
                    .document(project.id)
                    .setData(project.toFirestoreData(), merge: true)
                
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
            }
        )
    }

    static var testValue: FirebaseClient {
        .init(
//            deleteAllForUser: { _ in },
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
            return nil
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
            ownerId: data["ownerId"] as? String,
            syncStatus: syncStatus
        )
    }
}
