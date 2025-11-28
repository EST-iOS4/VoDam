//
//  FileCloudClient.swift
//  Vodam
//
//  Created by 송영민 on 11/28/25.
//

import Dependencies
import FirebaseStorage
import Foundation

struct FileCloudClient {
    /// 로컬 파일을 Firebase Storage에 업로드하고, Storage 경로를 반환
    var uploadFile: @Sendable (_ ownerId: String, _ projectId: String, _ fileURL: URL) async throws -> String
    
    /// remotePath를 보고, 이 기기에 파일이 없으면 다운로드 후 로컬 경로를 반환
    var downloadFileIfNeeded: @Sendable (_ ownerId: String, _ projectId: String, _ remotePath: String, _ currentLocalPath: String?) async throws -> String
    
    /// Storage에서 파일 삭제
    var deleteFile: @Sendable (_ remotePath: String) async throws -> Void
}

extension FileCloudClient: DependencyKey {
    static let liveValue = FileCloudClient(
        uploadFile: { ownerId, projectId, fileURL in
            let storage = Storage.storage()
            
            let fileExtension = fileURL.pathExtension.lowercased()
            
            let (path, contentType) = getPathAndContentType(
                ownerId: ownerId,
                projectId: projectId,
                fileExtension: fileExtension
            )
            
            let ref = storage.reference(withPath: path)
            
            let metadata = StorageMetadata()
            metadata.contentType = contentType
            
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let uploadTask = ref.putFile(from: fileURL, metadata: metadata) { metadata, error in
                    if let error = error {
                        print("[FileCloud] 업로드 실패: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if metadata != nil {
                        print("[FileCloud] 업로드 완료: \(path)")
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "FileCloud",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "업로드는 성공했으나 메타데이터를 받지 못했습니다"]
                        ))
                    }
                }
                
                uploadTask.observe(.progress) { snapshot in
                    if let progress = snapshot.progress {
                        let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        print("[FileCloud] 업로드 진행: \(String(format: "%.1f", percentComplete))%")
                    }
                }
            }
            
            print("[FileCloud] upload 완료: \(path)")
            return path
        },
        
        downloadFileIfNeeded: { ownerId, projectId, remotePath, currentLocalPath in
            let fileManager = FileManager.default
            
            if
                let currentLocalPath,
                fileManager.fileExists(atPath: currentLocalPath)
            {
                print("[FileCloud] 로컬 파일 이미 존재: \(currentLocalPath)")
                return currentLocalPath
            }
            
            guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "FileCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Documents 디렉토리 없음"])
            }
            
            let pathExtension = (remotePath as NSString).pathExtension
            let localURL = docs.appendingPathComponent("\(projectId).\(pathExtension)")
            
            let storage = Storage.storage()
            let ref = storage.reference(withPath: remotePath)
            
            let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                ref.getData(maxSize: 100 * 1024 * 1024) { data, error in
                    if let error {
                        print("[FileCloud] 다운로드 실패: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "FileCloud",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "다운로드 데이터 없음"]
                        ))
                    }
                }
            }
            
            try data.write(to: localURL, options: .atomic)
            
            print("[FileCloud] 다운로드 완료: \(remotePath) → \(localURL.path)")
            return localURL.path
        },
        
        deleteFile: { remotePath in
            let storage = Storage.storage()
            let ref = storage.reference(withPath: remotePath)
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ref.delete { error in
                    if let error {
                        print("[FileCloud] 삭제 실패: \(remotePath) - \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        print("[FileCloud] 삭제 완료: \(remotePath)")
                        continuation.resume()
                    }
                }
            }
        }
    )
    
    private static func getPathAndContentType(
        ownerId: String,
        projectId: String,
        fileExtension: String
    ) -> (path: String, contentType: String) {
        let ext = fileExtension.lowercased()
        
        if ["m4a", "mp3", "wav", "aac", "caf"].contains(ext) {
            return (
                path: "users/\(ownerId)/audio/\(projectId).\(ext)",
                contentType: "audio/\(ext)"
            )
        }
        
        if ext == "pdf" {
            return (
                path: "users/\(ownerId)/pdfs/\(projectId).pdf",
                contentType: "application/pdf"
            )
        }
        
        switch ext {
        case "jpg", "jpeg":
            return (
                path: "users/\(ownerId)/images/\(projectId).\(ext)",
                contentType: "image/jpeg"
            )
        case "png":
            return (
                path: "users/\(ownerId)/images/\(projectId).png",
                contentType: "image/png"
            )
        case "heic":
            return (
                path: "users/\(ownerId)/images/\(projectId).heic",
                contentType: "image/heic"
            )
        case "gif":
            return (
                path: "users/\(ownerId)/images/\(projectId).gif",
                contentType: "image/gif"
            )
        default:
            return (
                path: "users/\(ownerId)/files/\(projectId).\(ext)",
                contentType: "application/octet-stream"
            )
        }
    }
}

extension DependencyValues {
    var fileCloudClient: FileCloudClient {
        get { self[FileCloudClient.self] }
        set { self[FileCloudClient.self] = newValue }
    }
}
