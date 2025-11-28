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
    var uploadFile: @Sendable (_ ownerId: String, _ projectId: String, _ fileURL: URL) async throws -> String
    var downloadFileIfNeeded: @Sendable (_ ownerId: String, _ projectId: String, _ remotePath: String, _ currentLocalPath: String?) async throws -> String
    var deleteFile: @Sendable (_ remotePath: String) async throws -> Void
    var listFiles: @Sendable (_ path: String) async throws -> [String]
}

extension FileCloudClient: DependencyKey {
    static let liveValue = FileCloudClient(
        uploadFile: { ownerId, projectId, fileURL in
            print("📤 [FileCloud] 업로드 시작")
            print("   - Owner: \(ownerId)")
            print("   - Project: \(projectId)")
            print("   - File: \(fileURL.path)")
            
            let storage = Storage.storage()
            
            // 파일 존재 확인
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: fileURL.path) else {
                print("❌ [FileCloud] 파일이 존재하지 않음: \(fileURL.path)")
                throw NSError(domain: "FileCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "파일이 존재하지 않습니다"])
            }
            
            // 파일 크기 확인
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📦 [FileCloud] 파일 크기: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
                
                if fileSize == 0 {
                    print("❌ [FileCloud] 파일 크기가 0입니다")
                    throw NSError(domain: "FileCloud", code: -2, userInfo: [NSLocalizedDescriptionKey: "파일 크기가 0입니다"])
                }
            } catch {
                print("❌ [FileCloud] 파일 속성 조회 실패: \(error)")
                throw error
            }
            
            let fileExtension = fileURL.pathExtension.lowercased()
            print("📝 [FileCloud] 파일 확장자: \(fileExtension)")
            
            let (path, contentType) = getPathAndContentType(
                ownerId: ownerId,
                projectId: projectId,
                fileExtension: fileExtension
            )
            
            print("🔗 [FileCloud] Storage 경로: \(path)")
            print("📄 [FileCloud] Content-Type: \(contentType)")
            
            let ref = storage.reference(withPath: path)
            
            let metadata = StorageMetadata()
            metadata.contentType = contentType
            
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                print("⏳ [FileCloud] 업로드 작업 시작...")
                
                let uploadTask = ref.putFile(from: fileURL, metadata: metadata) { metadata, error in
                    if let error = error {
                        print("❌ [FileCloud] 업로드 실패: \(error.localizedDescription)")
                        if let nsError = error as NSError? {
                            print("   - Domain: \(nsError.domain)")
                            print("   - Code: \(nsError.code)")
                            print("   - UserInfo: \(nsError.userInfo)")
                        }
                        continuation.resume(throwing: error)
                    } else if let metadata = metadata {
                        print("✅ [FileCloud] 업로드 완료")
                        print("   - Path: \(metadata.path ?? "nil")")
                        print("   - Name: \(metadata.name ?? "nil")")
                        print("   - Size: \(metadata.size) bytes")
                        print("   - Content-Type: \(metadata.contentType ?? "nil")")
                        continuation.resume()
                    } else {
                        print("❌ [FileCloud] 업로드는 성공했으나 메타데이터 없음")
                        continuation.resume(throwing: NSError(
                            domain: "FileCloud",
                            code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "업로드는 성공했으나 메타데이터를 받지 못했습니다"]
                        ))
                    }
                }
                
                uploadTask.observe(.progress) { snapshot in
                    if let progress = snapshot.progress {
                        let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        print("📊 [FileCloud] 업로드 진행: \(String(format: "%.1f", percentComplete))% (\(progress.completedUnitCount)/\(progress.totalUnitCount) bytes)")
                    }
                }
                
                uploadTask.observe(.failure) { snapshot in
                    if let error = snapshot.error {
                        print("❌ [FileCloud] 업로드 실패 이벤트: \(error.localizedDescription)")
                    }
                }
                
                uploadTask.observe(.success) { snapshot in
                    print("✅ [FileCloud] 업로드 성공 이벤트")
                }
            }
            
            print("🎉 [FileCloud] upload 완료: \(path)")
            return path
        },
        
        downloadFileIfNeeded: { ownerId, projectId, remotePath, currentLocalPath in
            let fileManager = FileManager.default
            
            if
                let currentLocalPath,
                fileManager.fileExists(atPath: currentLocalPath)
            {
                print("✅ [FileCloud] 로컬 파일 이미 존재: \(currentLocalPath)")
                return currentLocalPath
            }
            
            guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "FileCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Documents 디렉토리 없음"])
            }
            
            let pathExtension = (remotePath as NSString).pathExtension
            let localURL = docs.appendingPathComponent("\(projectId).\(pathExtension)")
            
            print("📥 [FileCloud] 다운로드 시작: \(remotePath)")
            
            let storage = Storage.storage()
            let ref = storage.reference(withPath: remotePath)
            
            let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                ref.getData(maxSize: 100 * 1024 * 1024) { data, error in
                    if let error {
                        print("❌ [FileCloud] 다운로드 실패: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let data {
                        print("✅ [FileCloud] 다운로드 완료: \(data.count) bytes")
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
            
            print("✅ [FileCloud] 다운로드 완료: \(remotePath) → \(localURL.path)")
            return localURL.path
        },
        
        deleteFile: { remotePath in
            print("🗑️ [FileCloud] 삭제 시작: \(remotePath)")
            let storage = Storage.storage()
            let ref = storage.reference(withPath: remotePath)
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ref.delete { error in
                    if let error {
                        print("❌ [FileCloud] 삭제 실패: \(remotePath) - \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        print("✅ [FileCloud] 삭제 완료: \(remotePath)")
                        continuation.resume()
                    }
                }
            }
        },
        
        listFiles: { path in
            print("📂 [FileCloud] 파일 목록 조회: \(path)")
            let storage = Storage.storage()
            let ref = storage.reference(withPath: path)
            
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageListResult, Error>) in
                ref.listAll { result, error in
                    if let error {
                        print("❌ [FileCloud] 파일 목록 조회 실패: \(path) - \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let result {
                        print("✅ [FileCloud] 파일 목록 조회 완료: \(path) - \(result.items.count)개")
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "FileCloud",
                            code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "파일 목록 없음"]
                        ))
                    }
                }
            }
            
            return result.items.map { $0.fullPath }
        }
    )
    
    static let testValue = FileCloudClient(
        uploadFile: { _, _, _ in "test/path" },
        downloadFileIfNeeded: { _, _, _, _ in "/tmp/test.m4a" },
        deleteFile: { _ in },
        listFiles: { _ in [] }
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
