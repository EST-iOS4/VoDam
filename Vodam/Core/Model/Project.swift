//
//  Project.swift
//  Vodam
//
//  Created by 이건준 on 11/24/25.
//

import Foundation
import IdentifiedCollections

struct Project: Hashable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var creationDate: Date
    var category: ProjectCategory
    var isFavorite: Bool
    
    var filePath: String? = nil
    var fileLength: Int? = nil
    var transcript: String?
    var syncStatus: SyncStatus = .localOnly
    var summary: String? = nil
    
    static let mock: IdentifiedArrayOf<Project> = [
        Project(
            id: UUID(),
            name: "파일로 저장된 테스트 프로젝트",
            creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 19)) ?? Date(),
            category: .file,
            isFavorite: false,
            filePath: nil,
            fileLength: nil,
            syncStatus: .localOnly
        ),
    ]
}
// RecordingMetadata 변환
extension Project {
    init(from recording: RecordingMetadata) {
        self.id = UUID(uuidString: recording.id) ?? UUID()
        self.name = recording.filename
        self.creationDate = recording.createdAt
        self.category = .audio
        self.isFavorite = false
    }
}
