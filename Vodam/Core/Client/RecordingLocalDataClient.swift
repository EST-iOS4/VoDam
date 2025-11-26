//
//  RecordingLocalDataClient.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Dependencies
import Foundation
import SwiftData

struct RecordingLocalDataClient {
    var save:
        @Sendable (
            _ context: ModelContext, _ url: URL, _ length: Int,
            _ ownerId: String?
        ) throws -> RecordingPayload
    var deleteAllForOwner:
        @Sendable (_ context: ModelContext, _ ownerId: String) throws -> Void
}

extension RecordingLocalDataClient: DependencyKey {
    static var liveValue: RecordingLocalDataClient {
        .init(
            save: { context, url, length, ownerId in
                let model = RecordingModel(
                    filename: url.lastPathComponent,
                    filePath: url.path,
                    length: length,
                    createdAt: .now,
                    ownerId: ownerId,
                    syncStatus: .localOnly
                )

                context.insert(model)
                try context.save()
                print(
                    "SwiftData 저장 성공 → \(url.lastPathComponent), ownerId: \(ownerId ?? "nil")"
                )

                return RecordingPayload(model: model)
            },
            deleteAllForOwner: { context, ownerId in
                let descriptor = FetchDescriptor<RecordingModel>(
                    predicate: #Predicate { recording in
                        recording.ownerId == ownerId
                    }
                )

                let recordings = try context.fetch(descriptor)

                guard !recordings.isEmpty else {
                    print("🧹 삭제 대상 로컬 녹음 없음 (ownerId: \(ownerId))")
                    return
                }

                for recording in recordings {
                    context.delete(recording)
                }

                try context.save()
                print(
                    "SwiftData에서 ownerId=\(ownerId) 녹음 \(recordings.count)개 삭제"
                )
            }
        )
    }

    static var testValue: RecordingLocalDataClient {
        .init(
            save: { _, url, length, ownerId in
                return RecordingPayload(
                    id: UUID().uuidString,
                    filename: url.lastPathComponent,
                    filePath: url.path,
                    length: length,
                    createdAt: .now,
                    ownerId: ownerId,
                    syncStatus: .localOnly
                )
            },
            deleteAllForOwner: { _, _ in }
        )
    }
}
extension DependencyValues {
    var recordingLocalDataClient: RecordingLocalDataClient {
        get { self[RecordingLocalDataClient.self] }
        set { self[RecordingLocalDataClient.self] = newValue }
    }
}
