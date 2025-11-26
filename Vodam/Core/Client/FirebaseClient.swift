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
    var uploadRecordings:
        @Sendable (_ ownerId: String, _ recordings: [RecordingPayload])
            async throws -> Void

    var fetchRecordings:
        @Sendable (_ ownerId: String) async throws -> [RecordingPayload]

    var deleteAllForUser: @Sendable (_ ownerId: String) async throws -> Void
}

extension FirebaseClient: DependencyKey {
    static var liveValue: FirebaseClient {
        .init(
            uploadRecordings: { ownerId, recordings in
                let db = Firestore.firestore()

                let batch = db.batch()

                for recording in recordings {
                    let docRef =
                        db
                        .collection("users")
                        .document(ownerId)
                        .collection("recordings")
                        .document(recording.id)

                    batch.setData(
                        recording.toFirestoreData(),
                        forDocument: docRef
                    )
                }

                try await batch.commit()
                print(
                    "[FirebaseClient] Firestore 업로드 완료: ownerId=\(ownerId), count=\(recordings.count)"
                )
            },
            fetchRecordings: { ownerId in
                print(
                    "[FirebaseClient] fetchRecordings(ownerId: \(ownerId)) 호출 (아직 구현 전)"
                )
                return []
            },
            deleteAllForUser: { ownerId in
                print(
                    "[FirebaseClient] deleteAllForUser(ownerId: \(ownerId)) 호출 (아직 구현 전)"
                )
            }
        )
    }

    static var testValue: FirebaseClient {
        .init(
            uploadRecordings: { _, _ in },
            fetchRecordings: { _ in [] },
            deleteAllForUser: { _ in }
        )
    }
}

extension DependencyValues {
    var firebaseClient: FirebaseClient {
        get { self[FirebaseClient.self] }
        set { self[FirebaseClient.self] = newValue }
    }
}

extension RecordingPayload {
    fileprivate func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "filename": filename,
            "filePath": filePath,
            "length": length,
            "createdAt": Timestamp(date: createdAt),
            "syncStatus": syncStatus.rawValue,
        ]

        if let ownerId {
            data["ownerId"] = ownerId
        }

        return data
    }
}
