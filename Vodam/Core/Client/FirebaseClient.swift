//
//  FirebaseClient.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Dependencies
import Foundation
import FirebaseFirestore

struct FirebaseClient {
    var uploadRecordings: @Sendable (_ ownerId: String, _ recordings: [RecordingPayload]) async throws -> Void

    var fetchRecordings: @Sendable (_ ownerId: String) async throws -> [RecordingPayload]

    var deleteAllForUser: @Sendable (_ ownerId: String) async throws -> Void
}

extension FirebaseClient: DependencyKey {
    static var liveValue: FirebaseClient {
        .init(
            uploadRecordings: { ownerId, recordings in
                print("[FirebaseClient] uploadRecordings(ownerId: \(ownerId), count: \(recordings.count)) 호출 (아직 구현 전)")
            },
            fetchRecordings: { ownerId in
                print("[FirebaseClient] fetchRecordings(ownerId: \(ownerId)) 호출 (아직 구현 전)")
                return []
            },
            deleteAllForUser: { ownerId in
                print("🔥 [FirebaseClient] deleteAllForUser(ownerId: \(ownerId)) 호출 (아직 구현 전)")
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
