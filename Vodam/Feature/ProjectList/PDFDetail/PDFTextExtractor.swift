//
//  PDFTextExtractor.swift
//  Vodam
//
//  Created by 송영민 on 11/28/25.
//

import Foundation
import PDFKit

struct PDFTextExtractor {
    static func extractText(from url: URL) -> String? {
        print("[PDFTextExtractor] 텍스트 추출 시작: \(url.lastPathComponent)")
        
        guard let pdfDocument = PDFDocument(url: url) else {
            print("[PDFTextExtractor] PDF 문서 로드 실패")
            return nil
        }
        
        let pageCount = pdfDocument.pageCount
        print("[PDFTextExtractor] 총 페이지 수: \(pageCount)")
        
        var extractedText = ""
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                print("[PDFTextExtractor] 페이지 \(pageIndex + 1) 로드 실패")
                continue
            }
            
            if let pageText = page.string {
                extractedText += pageText
                extractedText += "\n\n" // 페이지 구분
                
                print("[PDFTextExtractor] 페이지 \(pageIndex + 1) 추출 완료 (\(pageText.count)자)")
            }
        }
        
        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            print("[PDFTextExtractor] 추출된 텍스트가 없습니다")
            return nil
        }
        
        print("[PDFTextExtractor] 전체 추출 완료: \(trimmedText.count)자")
        return trimmedText
    }
    
    static func extractText(from url: URL, maxLength: Int = 10000) -> String? {
        guard var text = extractText(from: url) else {
            return nil
        }
        
        if text.count > maxLength {
            text = String(text.prefix(maxLength))
            print("[PDFTextExtractor] 텍스트 잘림: \(maxLength)자로 제한")
        }
        
        return text
    }
}
