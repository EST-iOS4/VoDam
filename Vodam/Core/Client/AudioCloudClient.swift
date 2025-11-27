//
//  AudioCloudClient.swift
//  Vodam
//
//  Created by 송영민 on 11/27/25.
//

import Dependencies
import FirebaseStorage
import Foundation

struct AudioCloudClient {
    /// 로컬 오디오 파일을 Firebase Storage에 업로드하고, Storage 경로(문자열)를 반환
    var uploadAudio: @Sendable (_ ownerId: String, _ projectId: String, _ fileURL: URL) async throws -> String

    /// remotePath를 보고, 이 기기에 파일이 없으면 다운로드 후 로컬 경로를 반환
    var downloadAudioIfNeeded: @Sendable (_ ownerId: String, _ projectId: String, _ remotePath: String, _ currentLocalPath: String?) async throws -> String
}

extension AudioCloudClient: DependencyKey {
    static let liveValue = AudioCloudClient(
        uploadAudio: { ownerId, projectId, fileURL in
            let storage = Storage.storage()
            let path = "users/\(ownerId)/projects/\(projectId).m4a"
            let ref = storage.reference(withPath: path)

            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let uploadTask = ref.putFile(from: fileURL, metadata: nil) { metadata, error in
                    if let error = error {
                        print("[AudioCloud] 업로드 실패: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if metadata != nil {
                        print("[AudioCloud] 업로드 완료: \(path)")
                        continuation.resume()
                    } else {
                        print("[AudioCloud] 메타데이터 없음")
                        continuation.resume(throwing: NSError(
                            domain: "AudioCloud",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "업로드는 성공했으나 메타데이터를 받지 못했습니다"]
                        ))
                    }
                }
                
                uploadTask.observe(.progress) { snapshot in
                    if let progress = snapshot.progress {
                        let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        print("[AudioCloud] 업로드 진행: \(String(format: "%.1f", percentComplete))%")
                    }
                }
            }

            print("[AudioCloud] upload 완료: \(path)")
            return path
        },
        downloadAudioIfNeeded: { ownerId, projectId, remotePath, currentLocalPath in
            let fileManager = FileManager.default

            if
                let currentLocalPath,
                fileManager.fileExists(atPath: currentLocalPath)
            {
                print("[AudioCloud] 로컬 파일 이미 존재: \(currentLocalPath)")
                return currentLocalPath
            }

            guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "AudioCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Documents 디렉토리 없음"])
            }

            let localURL = docs.appendingPathComponent("\(projectId).m4a")

            let storage = Storage.storage()
            let ref = storage.reference(withPath: remotePath)

            let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                ref.getData(maxSize: 50 * 1024 * 1024) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: NSError(domain: "AudioCloud", code: -2, userInfo: [NSLocalizedDescriptionKey: "다운로드 데이터 없음"]))
                    }
                }
            }

            try data.write(to: localURL, options: .atomic)

            print("[AudioCloud] 다운로드 완료: \(remotePath) → \(localURL.path)")
            return localURL.path
        }
    )
}

extension DependencyValues {
    var audioCloudClient: AudioCloudClient {
        get { self[AudioCloudClient.self] }
        set { self[AudioCloudClient.self] = newValue }
    }
}
