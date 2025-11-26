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
    var save: @Sendable (_ context: ModelContext, _ url: URL, _ length: Int) throws -> Void
}

extension RecordingLocalDataClient: DependencyKey {
    static var liveValue: RecordingLocalDataClient {
        .init(
            save: { context, url, length in
                let model = RecordingModel(
                    filename: url.lastPathComponent,
                    filePath: url.path,
                    length: length,
                    createdAt: .now
                    // ownerId, syncStatus는 일단 기본값(nil, .localOnly) 사용
                )

                context.insert(model)

                do {
                    try context.save()
                    print("SwiftData 저장 성공 → \(url.lastPathComponent)")
                } catch {
                    print("SwiftData 저장 실패: \(error)")
                    throw error
                }
            }
        )
    }

    static var testValue: RecordingLocalDataClient {
        .init(
            save: { _, _, _ in
    
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
