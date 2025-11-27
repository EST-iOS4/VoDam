//
//  RecordingPayload.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Foundation

struct ProjectPayload: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let creationDate: Date
    let category: ProjectCategory
    let isFavorite: Bool
    let filePath: String?
    let fileLength: Int?
    let transcript: String?
    let ownerId: String?
    let syncStatus: SyncStatus
    
    let remoteAudioPath: String?
    init(
        id: String,
        name: String,
        creationDate: Date,
        category: ProjectCategory,
        isFavorite: Bool,
        filePath: String?,
        fileLength: Int?,
        transcript: String?,
        ownerId: String?,
        syncStatus: SyncStatus,
        remoteAudioPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
        self.category = category
        self.isFavorite = isFavorite
        self.filePath = filePath
        self.fileLength = fileLength
        self.transcript = transcript
        self.ownerId = ownerId
        self.syncStatus = syncStatus
        self.remoteAudioPath = remoteAudioPath
    }
    
    init(model: ProjectModel) {
        self.id = model.id
        self.name = model.name
        self.creationDate = model.creationDate
        self.category = model.category
        self.isFavorite = model.isFavorite
        self.filePath = model.filePath
        self.fileLength = model.fileLength
        self.transcript = model.transcript
        self.ownerId = model.ownerId
        self.syncStatus = model.syncStatus
        self.remoteAudioPath = model.remoteAudioPath
    }
}
