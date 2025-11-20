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

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}
