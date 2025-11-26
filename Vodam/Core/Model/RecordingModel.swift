//
//  RecordingModel.swift
//  VoDam
//

import SwiftData
import Foundation

@Model
final class RecordingModel {
    @Attribute(.unique) var id: UUID
    var filename: String
    var filePath: String
    var length: Int    // 초 단위 녹음 길이
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
