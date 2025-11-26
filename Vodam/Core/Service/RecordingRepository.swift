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
    
    static let liveValue: RecordingRepository = {
        let container = try! ModelContainer(for: RecordingModel.self)
        let context = ModelContext(container)
        
        return RecordingRepository(
            saveLocal: { metadata in
                let model = RecordingModel(
                    id: metadata.id,
                    filename: metadata.filename,
                    filePath: metadata.filePath,
                    length: metadata.length,
                    createdAt: metadata.createdAt
                )
                context.insert(model)
                try context.save()
            },
            
            fetchAll: {
                let descriptor = FetchDescriptor<RecordingModel>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                let models = try context.fetch(descriptor)
                return models.map { model in
                    RecordingMetadata(
                        id: model.id,
                        filename: model.filename,
                        filePath: model.filePath,
                        length: model.length,
                        createdAt: model.createdAt
                    )
                }
            },
            
            delete: { id in
                let descriptor = FetchDescriptor<RecordingModel>()
                let models = try context.fetch(descriptor)
                if let model = models.first(where: { $0.id == id }) {
                    context.delete(model)
                    try context.save()
                }
            },
            
            saveRemote: { metadata in
                print("🌐 Firebase 준비 예정: \(metadata.filename)")
            },
            
            isLoggedIn: { false }
        )
    }()
}

// MARK: - DependencyValues 확장
extension DependencyValues {
    var recordingRepository: RecordingRepository {
        get { self[RecordingRepositoryKey.self] }
        set { self[RecordingRepositoryKey.self] = newValue }
    }
}
