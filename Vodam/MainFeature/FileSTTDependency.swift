//
//  FileSTTDependency.swift
//  Vodam
//
//  Created by 강지원 on 11/26/25.
//

import Dependencies

extension AudioFileSTTClient: DependencyKey {
    static let liveValue = AudioFileSTTClient.live
}

extension DependencyValues {
    var audioFileSTTClient: AudioFileSTTClient {
        get { self[AudioFileSTTClient.self] }
        set { self[AudioFileSTTClient.self] = newValue }
    }
}
