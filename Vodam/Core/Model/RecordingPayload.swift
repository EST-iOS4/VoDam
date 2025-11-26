//
//  RecordingPayload.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Foundation

struct RecordingPayload: Codable, Sendable {
    let id: String
    let filename: String
    let filePath: String
    let length: Int
    let createdAt: Date
    let ownerId: String?
    let syncStatus: SyncStatus

    init(
        id: String,
        filename: String,
        filePath: String,
        length: Int,
        createdAt: Date,
        ownerId: String?,
        syncStatus: SyncStatus
    ) {
        self.id = id
        self.filename = filename
        self.filePath = filePath
        self.length = length
        self.createdAt = createdAt
        self.ownerId = ownerId
        self.syncStatus = syncStatus
    }
}

extension RecordingPayload {
    init(model: RecordingModel) {
        self.id = model.id
        self.filename = model.filename
        self.filePath = model.filePath
        self.length = model.length
        self.createdAt = model.createdAt
        self.ownerId = model.ownerId
        self.syncStatus = model.syncStatus
    }
}
