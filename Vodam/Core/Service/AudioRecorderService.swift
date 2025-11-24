//
//  AudioRecorderService.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import Foundation

struct AudioRecorderService {
    var startRecording: () throws -> URL
    var pauseRecording: () -> Void
    var resumeRecording: () -> Void
    var stopRecording: () -> URL?
}
