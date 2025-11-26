//
//  FileSTTClient.swift
//  Vodam
//
//  Created by 강지원 on 11/26/25.
//

import Foundation
import Speech

struct AudioFileSTTClient {
    var transcribe:
        @Sendable (URL) async -> Result<String, FileButtonFeature.STTError>
}

extension AudioFileSTTClient {
    static let live = AudioFileSTTClient { url in
        return await transcribeAudioFile(url: url)
    }
}

// 수정된 STTError 타입 반영
func transcribeAudioFile(url: URL) async -> Result<
    String, FileButtonFeature.STTError
> {

    return await withCheckedContinuation { continuation in

        // 1. 보안 스코프 열기
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

        // 2. iCloud 파일이면 로컬로 먼저 다운로드
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
            } catch {
                continuation.resume(
                    returning: .failure(
                        .failed(
                            "iCloud에서 파일 다운로드 실패: \(error.localizedDescription)"
                        )
                    )
                )
                return
            }
        }

        // 3. temp 디렉토리로 파일 복사
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

        // 4. Speech 권한 확인
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

            // 5. 실제 STT
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
