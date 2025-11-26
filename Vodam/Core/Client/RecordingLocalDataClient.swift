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
    var save: @Sendable (_ context: ModelContext, _ url: URL, _ length: Int, _ ownerId: String?) throws -> RecordingPayload
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

                do {
                    try context.save()
                    print("SwiftData 저장 성공 → \(url.lastPathComponent), ownerId: \(ownerId ?? "nil")")
                    return RecordingPayload(model: model)
                } catch {
                    print("SwiftData 저장 실패: \(error)")
                    throw error
                }
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
                        }
                    )
                }
            }
extension DependencyValues {
    var recordingLocalDataClient: RecordingLocalDataClient {
        get { self[RecordingLocalDataClient.self] }
        set { self[RecordingLocalDataClient.self] = newValue }
    }
}
