//
//  RecordingModel.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import Foundation
import SwiftData

@Model
final class ProjectModel {
    @Attribute(.unique) var id: String
    var name: String
    var creationDate: Date
    var categoryRaw: String
    var isFavorite: Bool
    
    var filePath: String?
    var fileLength: Int?
    
    var transcript: String?
    var summary: String?
    
    var ownerId: String?
    var syncStatusRaw: String
    var remoteAudioPath: String?
    
    var category: ProjectCategory {
        get { ProjectCategory(rawValue: categoryRaw) ?? .audio }
        set { categoryRaw = newValue.rawValue }
    }
    
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        creationDate: Date = .now,
        category: ProjectCategory,
        isFavorite: Bool = false,
        filePath: String? = nil,
        fileLength: Int? = nil,
        transcript: String? = nil,
        summary: String? = nil,
        ownerId: String? = nil,
        syncStatus: SyncStatus = .localOnly,
        remoteAudioPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
        self.categoryRaw = category.rawValue
        self.isFavorite = isFavorite
        self.filePath = filePath
        self.fileLength = fileLength
        self.transcript = transcript
        self.summary = summary
        self.ownerId = ownerId
        self.syncStatusRaw = syncStatus.rawValue
        self.remoteAudioPath = remoteAudioPath
    }
}

extension ProjectModel {
    func toProject() -> Project {
        Project(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            creationDate: creationDate,
            category: category,
            isFavorite: isFavorite,
            filePath: filePath,
            fileLength: fileLength,
            transcript: transcript,
            syncStatus: syncStatus,
            summary: summary,
            remoteAudioPath: remoteAudioPath  // 추가됨
        )
    }
}

extension Project {
    init(model: ProjectModel) {
        self.id = UUID(uuidString: model.id) ?? UUID()
        self.name = model.name
        self.creationDate = model.creationDate
        self.category = model.category
        self.isFavorite = model.isFavorite
        self.filePath = model.filePath
        self.fileLength = model.fileLength
        self.transcript = model.transcript
        self.summary = model.summary
        self.syncStatus = model.syncStatus
        self.remoteAudioPath = model.remoteAudioPath  // 추가됨
    }
}
