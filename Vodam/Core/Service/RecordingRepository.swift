//
//  RecordingRepository.swift
//  VoDam
//
//  Created by 강지원 on 11/20/25.
//

import Foundation
import ComposableArchitecture

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
    /// SwiftData 저장
    var saveLocal: (RecordingMetadata) async throws -> Void

    /// Firebase 저장 (추후 구현)
    var saveRemote: (RecordingMetadata) async throws -> Void

    /// 로그인 여부 (Firebase Auth 연결 시 사용)
    var isLoggedIn: () -> Bool
}


// MARK: - DependencyKey 등록
enum RecordingRepositoryKey: DependencyKey {

    static let liveValue: RecordingRepository = RecordingRepository(

        saveLocal: { metadata in
            // 실제 SwiftData 저장 로직은 View에서 ModelContext로 처리
            // 여기서는 저장 요청만 알림
            print("📥 로컬 저장 요청됨: \(metadata.filename)")
        },

        saveRemote: { metadata in
            print("🌐 원격 저장 요청됨 (Firebase 준비 예정): \(metadata.filename)")
        },

        isLoggedIn: {
            // TODO: Firebase Auth 붙이면 변경
            return false
        }
    )
}


// MARK: - DependencyValues 확장
extension DependencyValues {
    var recordingRepository: RecordingRepository {
        get { self[RecordingRepositoryKey.self] }
        set { self[RecordingRepositoryKey.self] = newValue }
    }
}
