//
//  PDFOCRClient.swift
//  VoDam
//
//  Created by 강지원 on 12/3/25.
//

//
//  PDFOCRClient.swift
//  VoDam
//

import Foundation
import Vision
import PDFKit
import ComposableArchitecture

struct PDFOCRClient {
    var extractText: @Sendable (URL, @Sendable @escaping (Double) async -> Void) async -> Result<String, PDFOCRError>
}

enum PDFOCRError: Error, Equatable {
    case fileAccessDenied
    case pdfLoadFailed
    case ocrFailed(String)
}

extension PDFOCRClient: DependencyKey {
    static let liveValue = PDFOCRClient(
        extractText: { url, progressHandler in
            await extractTextFromPDF(url: url, progressHandler: progressHandler)
        }
    )
}

extension DependencyValues {
    var pdfOCRClient: PDFOCRClient {
        get { self[PDFOCRClient.self] }
        set { self[PDFOCRClient.self] = newValue }
    }
}

// MARK: - PDF OCR 구현

private func extractTextFromPDF(
    url: URL,
    progressHandler: @Sendable @escaping (Double) async -> Void
) async -> Result<String, PDFOCRError> {
    
    // Security scoped resource 접근
    let allowed = url.startAccessingSecurityScopedResource()
    defer {
        if allowed {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    // PDF를 임시 디렉토리로 복사
    let fileManager = FileManager.default
    let tempURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("pdf")
    
    do {
        if fileManager.fileExists(atPath: tempURL.path) {
            try fileManager.removeItem(at: tempURL)
        }
        try fileManager.copyItem(at: url, to: tempURL)
    } catch {
        return .failure(.fileAccessDenied)
    }
    
    defer {
        try? fileManager.removeItem(at: tempURL)
    }
    
    // PDF 로드
    guard let pdfDocument = PDFDocument(url: tempURL) else {
        return .failure(.pdfLoadFailed)
    }
    
    let pageCount = pdfDocument.pageCount
    guard pageCount > 0 else {
        return .failure(.pdfLoadFailed)
    }
    
    print("📄 PDF 페이지 수: \(pageCount)")
    
    var allText: [String] = []
    
    for pageIndex in 0..<pageCount {
        guard let page = pdfDocument.page(at: pageIndex) else { continue }
        
        // 먼저 내장 텍스트 추출 시도
        if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            allText.append(pageText)
            print("📄 페이지 \(pageIndex + 1): 내장 텍스트 추출 (\(pageText.count)자)")
        } else {
            // 내장 텍스트가 없으면 OCR 수행
            let ocrResult = await performOCR(on: page)
            if !ocrResult.isEmpty {
                allText.append(ocrResult)
                print("📄 페이지 \(pageIndex + 1): OCR 완료 (\(ocrResult.count)자)")
            }
        }
        
        // 진행률 업데이트
        let progress = Double(pageIndex + 1) / Double(pageCount)
        await progressHandler(progress)
    }
    
    let finalText = allText.joined(separator: "\n\n")
    
    if finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .failure(.ocrFailed("텍스트를 추출할 수 없습니다."))
    }
    
    print("📄 PDF OCR 완료: 총 \(finalText.count)자")
    return .success(finalText)
}

private func performOCR(on page: PDFPage) async -> String {
    // PDF 페이지를 이미지로 변환
    let pageRect = page.bounds(for: .mediaBox)
    let scale: CGFloat = 2.0 // 해상도 향상
    let imageSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
    
    let renderer = UIGraphicsImageRenderer(size: imageSize)
    let image = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: imageSize))
        
        context.cgContext.translateBy(x: 0, y: imageSize.height)
        context.cgContext.scaleBy(x: scale, y: -scale)
        
        page.draw(with: .mediaBox, to: context.cgContext)
    }
    
    guard let cgImage = image.cgImage else { return "" }
    
    // Vision OCR 수행
    return await withCheckedContinuation { continuation in
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                continuation.resume(returning: "")
                return
            }
            
            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            continuation.resume(returning: text)
        }
        
        // 한국어 + 영어 인식
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("OCR 실패: \(error)")
            continuation.resume(returning: "")
        }
    }
}
