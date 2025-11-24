//
//  RecordingLocalDataSource.swift
//  VoDam
//
//  Created by 강지원 on 11/20/25.
//

import SwiftData

final class RecordingLocalDataSource {

    let context: ModelContext
    init(context: ModelContext) {
        self.context = context
    }

    func save(_ metadata: RecordingMetadata) throws {
        let model = RecordingModel(
            id: metadata.id,
            filename: metadata.filename,
            filePath: metadata.filePath,
            length: metadata.length,
            createdAt: metadata.createdAt
        )
        context.insert(model)
        try context.save()
    }
}
