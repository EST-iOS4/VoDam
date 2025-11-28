//
//  FileSTTClient.swift
//  Vodam
//
//  Created by 강지원 on 11/26/25.
//

import Foundation
import Speech

struct AudioFileSTTClient {
    var transcribe: @Sendable (URL) async -> Result<String, FileButtonFeature.STTError>
    var transcribeInternal: @Sendable (URL) async -> Result<String, FileButtonFeature.STTError>
}

extension AudioFileSTTClient {
    static let live = AudioFileSTTClient(
        transcribe: { url in
            return await transcribeAudioFile(url: url)
        },
        transcribeInternal: { url in
            return await transcribeInternalAudioFile(url: url)
        }
    )
}

// MARK: - 외부 파일용 (파일 가져오기)
func transcribeAudioFile(url: URL) async -> Result<String, FileButtonFeature.STTError> {
    
    return await withCheckedContinuation { continuation in
        
        let allowed = url.startAccessingSecurityScopedResource()
        if !allowed {
            continuation.resume(
                returning: .failure(.failed("보안 스코프 권한을 얻지 못했습니다."))
            )
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
            } catch {
                continuation.resume(
                    returning: .failure(
                        .failed("iCloud에서 파일 다운로드 실패: \(error.localizedDescription)")
                    )
                )
                return
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
            continuation.resume(
                returning: .failure(
                    .failed("임시 파일 복사 실패: \(error.localizedDescription)")
                )
            )
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                continuation.resume(
                    returning: .failure(.failed("STT 권한이 없습니다."))
                )
                return
            }
            
            guard
                let recognizer = SFSpeechRecognizer(
                    locale: Locale(identifier: "ko-KR")
                ),
                recognizer.isAvailable
            else {
                continuation.resume(
                    returning: .failure(.failed("SpeechRecognizer 사용 불가"))
                )
                return
            }
        
            let request = SFSpeechURLRecognitionRequest(url: localURL)
            var finalText = ""
            
            _ = recognizer.recognitionTask(with: request) { result, error in
                
                if let error {
                    continuation.resume(
                        returning: .failure(.failed(error.localizedDescription))
                    )
                    return
                }
                
                if let result {
                    finalText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        continuation.resume(returning: .success(finalText))
                    }
                }
            }
        }
    }
}

// MARK: - 앱 내부 파일용 (녹음 파일)
func transcribeInternalAudioFile(url: URL) async -> Result<String, FileButtonFeature.STTError> {
    
    return await withCheckedContinuation { continuation in
        guard FileManager.default.fileExists(atPath: url.path) else {
            continuation.resume(
                returning: .failure(.failed("파일이 존재하지 않습니다: \(url.path)"))
            )
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                continuation.resume(
                    returning: .failure(.failed("STT 권한이 없습니다."))
                )
                return
            }
            
            guard
                let recognizer = SFSpeechRecognizer(
                    locale: Locale(identifier: "ko-KR")
                ),
                recognizer.isAvailable
            else {
                continuation.resume(
                    returning: .failure(.failed("SpeechRecognizer 사용 불가"))
                )
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            var finalText = ""
            
            _ = recognizer.recognitionTask(with: request) { result, error in
                
                if let error {
                    continuation.resume(
                        returning: .failure(.failed(error.localizedDescription))
                    )
                    return
                }
                
                if let result {
                    finalText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        continuation.resume(returning: .success(finalText))
                    }
                }
            }
        }
    }
}
