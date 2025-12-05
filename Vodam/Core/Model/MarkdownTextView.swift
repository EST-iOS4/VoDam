//
//  MarkdownTextView.swift
//  Vodam
//
//  Created by 송영민 on 12/2/25.
//

import SwiftUI

struct MarkdownTextView: View {
    let text: String
    let font: Font
    let linSpacing: CGFloat
    
    init(
        _ text: String,
        font: Font = .body,
        linSpacing: CGFloat = 6
    ) {
        self.text = text
        self.font = font
        self.linSpacing = linSpacing
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            if let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
                    .font(font)
                    .lineSpacing(linSpacing)
            } else {
                Text(text)
                    .font(font)
                    .lineSpacing(linSpacing)
            }
        } else {
            Text(text)
                .font(font)
                .lineSpacing(linSpacing)
        }
    }
    
    private func makeAttributedString() -> AttributedString? {
            guard var attributed = try? AttributedString(markdown: text) else {
                return nil
            }
            
            let pretendardFont = UIFont(name: "Pretendard-Regular", size: 16) ?? .systemFont(ofSize: 16)
            attributed[attributed.startIndex..<attributed.endIndex].font = pretendardFont
            
            return attributed
        }
}
