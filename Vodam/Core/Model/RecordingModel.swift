//
//  RecordingModel.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import SwiftData
import Foundation

@Model
final class RecordingModel {
    @Attribute(.unique) var id: String
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
