//
//  RecordingModel.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import Foundation
import SwiftData

@Model
final class RecordingModel {
    @Attribute(.unique) var id: String
    var filename: String
    var filePath: String
    var length: Int
    var createdAt: Date

    var ownerId: String?
    var syncStatusRaw: String

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        filename: String,
        filePath: String,
        length: Int,
        createdAt: Date = .now,
        ownerId: String? = nil,
        syncStatus: SyncStatus = .localOnly
    ) {
        self.id = id
        self.filename = filename
        self.filePath = filePath
        self.length = length
        self.createdAt = createdAt
        self.ownerId = ownerId
        self.syncStatusRaw = syncStatus.rawValue
    }
}
