//
//  FileSTTClient.swift
//  Vodam
//
//  Created by 강지원 on 11/26/25.
//

import Foundation
import Speech
import AVFoundation

struct AudioFileSTTClient {
    var transcribe: @Sendable (URL, @Sendable @escaping (Double) async -> Void) async -> Result<String, FileButtonFeature.STTError>
    var transcribeInternal: @Sendable (URL, @Sendable @escaping (Double) async -> Void) async -> Result<String, FileButtonFeature.STTError>
}

extension AudioFileSTTClient {
    static let live = AudioFileSTTClient(
        transcribe: { url, progressHandler in
            return await transcribeAudioFile(url: url, progressHandler: progressHandler)
        },
        transcribeInternal: { url, progressHandler in
            return await transcribeInternalAudioFile(url: url, progressHandler: progressHandler)
        }
    )
}

private let chunkDuration: TimeInterval = 300

private func getAudioDuration(url: URL) async -> TimeInterval? {
    let asset = AVURLAsset(url: url)
    do {
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    } catch {
        return nil
    }
}

private func createTimeRanges(totalDuration: TimeInterval) -> [CMTimeRange] {
    var ranges: [CMTimeRange] = []
    var currentStart: TimeInterval = 0
    
    while currentStart < totalDuration {
        let start = CMTime(seconds: currentStart, preferredTimescale: 600)
        let duration = CMTime(seconds: min(chunkDuration, totalDuration - currentStart), preferredTimescale: 600)
        ranges.append(CMTimeRange(start: start, duration: duration))
        currentStart += chunkDuration
    }
    
    return ranges
}

private func exportChunk(from asset: AVURLAsset, timeRange: CMTimeRange, index: Int) async -> Result<URL, FileButtonFeature.STTError> {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("chunk_\(index)_\(UUID().uuidString).m4a")
    
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
        return .failure(.failed("오디오 내보내기 세션 생성 실패"))
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    exportSession.timeRange = timeRange
    
    await exportSession.export()
    
    guard exportSession.status == .completed else {
        let errorMsg = exportSession.error?.localizedDescription ?? "알 수 없는 오류"
        return .failure(.failed("청크 내보내기 실패: \(errorMsg)"))
    }
    
    return .success(outputURL)
}

private func transcribeSingleChunk(url: URL, recognizer: SFSpeechRecognizer) async -> Result<String, FileButtonFeature.STTError> {
    await withCheckedContinuation { continuation in
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        recognizer.recognitionTask(with: request) { result, error in
            if let error {
                continuation.resume(returning: .failure(.failed(error.localizedDescription)))
                return
            }
            
            if let result, result.isFinal {
                continuation.resume(returning: .success(result.bestTranscription.formattedString))
            }
        }
    }
}

private func transcribeWithChunks(
    localURL: URL,
    progressHandler: @Sendable @escaping (Double) async -> Void
) async -> Result<String, FileButtonFeature.STTError> {
    
    let authResult = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
        }
    }
    
    guard authResult == .authorized else {
        return .failure(.failed("STT 권한이 없습니다."))
    }
    
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")),
          recognizer.isAvailable else {
        return .failure(.failed("SpeechRecognizer 사용 불가"))
    }
    
    guard let duration = await getAudioDuration(url: localURL) else {
        return .failure(.failed("오디오 파일 길이를 확인할 수 없습니다."))
    }
    
    print("🎤 오디오 길이: \(Int(duration))초")
    
    if duration <= 300 {
        await progressHandler(0.5)
        let result = await transcribeSingleChunk(url: localURL, recognizer: recognizer)
        await progressHandler(1.0)
        return result
    }
    
    let asset = AVURLAsset(url: localURL)
    let timeRanges = createTimeRanges(totalDuration: duration)
    var transcripts: [String] = []
    
    print("🎤 \(timeRanges.count)개 청크로 분할 처리")
    
    for (index, timeRange) in timeRanges.enumerated() {
        print("🎤 청크 \(index + 1)/\(timeRanges.count) 처리 중...")
        
        let chunkResult = await exportChunk(from: asset, timeRange: timeRange, index: index)
        
        switch chunkResult {
        case .success(let chunkURL):
            defer { try? FileManager.default.removeItem(at: chunkURL) }
            
            let sttResult = await transcribeSingleChunk(url: chunkURL, recognizer: recognizer)
            
            switch sttResult {
            case .success(let text):
                if !text.isEmpty {
                    transcripts.append(text)
                }
            case .failure(let error):
                print("⚠️ 청크 \(index + 1) STT 실패: \(error)")
            }
            
        case .failure(let error):
            print("⚠️ 청크 \(index + 1) 내보내기 실패: \(error)")
        }
        
        let progress = Double(index + 1) / Double(timeRanges.count)
        await progressHandler(progress)
    }
    
    if transcripts.isEmpty {
        return .failure(.failed("모든 청크의 STT가 실패했습니다."))
    }
    
    return .success(transcripts.joined(separator: " "))
}

func transcribeAudioFile(
    url: URL,
    progressHandler: @Sendable @escaping (Double) async -> Void
) async -> Result<String, FileButtonFeature.STTError> {
    
    let allowed = url.startAccessingSecurityScopedResource()
    if !allowed {
        return .failure(.failed("보안 스코프 권한을 얻지 못했습니다."))
    }
    
    defer {
        url.stopAccessingSecurityScopedResource()
    }
    
    if !FileManager.default.fileExists(atPath: url.path) {
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            return .failure(.failed("iCloud에서 파일 다운로드 실패: \(error.localizedDescription)"))
        }
    }
    
    let fileManager = FileManager.default
    let ext = url.pathExtension
    let localURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)
    
    do {
        if fileManager.fileExists(atPath: localURL.path) {
            try fileManager.removeItem(at: localURL)
        }
        try fileManager.copyItem(at: url, to: localURL)
    } catch {
        return .failure(.failed("임시 파일 복사 실패: \(error.localizedDescription)"))
    }
    
    defer {
        try? fileManager.removeItem(at: localURL)
    }
    
    return await transcribeWithChunks(localURL: localURL, progressHandler: progressHandler)
}

func transcribeInternalAudioFile(
    url: URL,
    progressHandler: @Sendable @escaping (Double) async -> Void
) async -> Result<String, FileButtonFeature.STTError> {
    
    guard FileManager.default.fileExists(atPath: url.path) else {
        return .failure(.failed("파일이 존재하지 않습니다: \(url.path)"))
    }
    
    return await transcribeWithChunks(localURL: url, progressHandler: progressHandler)
}
