//
//  RecordingRepository.swift
//  VoDam
//
//  Created by 강지원 on 11/20/25.
//

import Foundation
import ComposableArchitecture
import SwiftData

// MARK: - RecordingMetadata
struct RecordingMetadata: Identifiable, Codable, Equatable {
    var id: String
    var filename: String
    var filePath: String
    var length: Int
    var createdAt: Date

    init(id: String = UUID().uuidString,
         filename: String,
         filePath: String,
         length: Int,
         createdAt: Date = .now) {
        self.id = id
        self.filename = filename
        self.filePath = filePath
        self.length = length
        self.createdAt = createdAt
    }
}

// MARK: - RecordingRepository 인터페이스
struct RecordingRepository {
    var saveLocal: (RecordingMetadata) async throws -> Void
    var fetchAll: () async throws -> [RecordingMetadata]
    var delete: (String) async throws -> Void
    var saveRemote: (RecordingMetadata) async throws -> Void
    var isLoggedIn: () -> Bool
}

// MARK: - DependencyKey 등록
enum RecordingRepositoryKey: DependencyKey {
    
    // ✅ ModelContainer 제거 - VodamApp에서 설정한 container 사용
    // ✅ 실제 저장은 projectLocalDataClient 사용 권장
    static let liveValue: RecordingRepository = RecordingRepository(
        saveLocal: { metadata in
            // projectLocalDataClient를 사용하세요
            print("⚠️ RecordingRepository.saveLocal 호출됨 - projectLocalDataClient 사용 권장")
        },
        fetchAll: {
            // projectLocalDataClient를 사용하세요
            print("⚠️ RecordingRepository.fetchAll 호출됨 - projectLocalDataClient 사용 권장")
            return []
        },
        delete: { id in
            // projectLocalDataClient를 사용하세요
            print("⚠️ RecordingRepository.delete 호출됨 - projectLocalDataClient 사용 권장")
        },
        saveRemote: { metadata in
            print("🌐 Firebase 준비 예정: \(metadata.filename)")
        },
        isLoggedIn: { false }
    )
}

// MARK: - DependencyValues 확장
extension DependencyValues {
    var recordingRepository: RecordingRepository {
        get { self[RecordingRepositoryKey.self] }
        set { self[RecordingRepositoryKey.self] = newValue }
    }
}
