//
//  ScriptView.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture
import UIKit

struct ScriptView: View {
    let store: StoreOf<ScriptFeature>
    private let preRollProgressOffset: Double = 0.01
    private let preRollSkipCharacterThreshold: Int = 5
    
    private let largeTextThreshold = 3000
    
    var body: some View {
        if store.text.count > largeTextThreshold {
            LargeScriptTextView(
                text: store.text,
                searchResults: store.searchResults,
                currentResultIndex: store.currentResultIndex
            )
        } else {
            smallTextBody
        }
    }
    
    private var smallTextBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    highlightedText
                        .font(.body)
                        .lineSpacing(6)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .onChange(of: store.currentResultIndex) { _, newIndex in
                withAnimation(.smooth) {
                    proxy.scrollTo("result_\(newIndex)", anchor: .center)
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var highlightedText: some View {
        if store.isPlaceholder {
            Text(store.text)
                .foregroundColor(.secondary)
        } else {
            let components = splitComponentsByWhitespace(
                buildHighlightComponents(
                    text: store.text,
                    results: store.searchResults,
                    currentIndex: store.currentResultIndex
                )
            )
            
            FlowLayout(
                components: components,
                isInteractionEnabled: true
            ) { component in
                handleTap(on: component)
            }
        }
    }
    
    private func buildHighlightComponents(
        text: String,
        results: [Range<String.Index>],
        currentIndex: Int
    ) -> [HighlightComponent] {
        var components: [HighlightComponent] = []
        var lastEndIndex = text.startIndex
        var currentOffset = 0
        
        for (index, range) in results.enumerated() {
            if lastEndIndex < range.lowerBound {
                let normalText = String(text[lastEndIndex..<range.lowerBound])
                components.append(HighlightComponent(
                    text: normalText,
                    type: .normal,
                    id: "normal_\(index)",
                    offset: currentOffset
                ))
                currentOffset += normalText.count
            }
            
            let highlightedText = String(text[range])
            let isCurrent = index == currentIndex
            components.append(HighlightComponent(
                text: highlightedText,
                type: isCurrent ? .current : .highlighted,
                id: "result_\(index)",
                offset: currentOffset
            ))
            currentOffset += highlightedText.count
            
            lastEndIndex = range.upperBound
        }
        
        if lastEndIndex < text.endIndex {
            let remainingText = String(text[lastEndIndex..<text.endIndex])
            components.append(HighlightComponent(
                text: remainingText,
                type: .normal,
                id: "remaining",
                offset: currentOffset
            ))
        }
        
        return components
    }
    
    private func splitComponentsByWhitespace(_ components: [HighlightComponent]) -> [HighlightComponent] {
        var result: [HighlightComponent] = []
        
        for component in components {
            let text = component.text
            var localStart = text.startIndex
            var localOffset = 0
            var partIndex = 0
            
            func appendPart(from start: String.Index, to end: String.Index) {
                guard start < end else { return }
                let substring = String(text[start..<end])
                let offset = component.offset + localOffset
                result.append(
                    HighlightComponent(
                        text: substring,
                        type: component.type,
                        id: "\(component.id)_\(partIndex)",
                        offset: offset
                    )
                )
                partIndex += 1
                localOffset += substring.count
            }
            
            for index in text.indices {
                if text[index].isWhitespace || text[index].isNewline {
                    appendPart(from: localStart, to: index)
                    
                    let nextIndex = text.index(after: index)
                    let whitespace = String(text[index..<nextIndex])
                    let offset = component.offset + localOffset
                    result.append(
                        HighlightComponent(
                            text: whitespace,
                            type: component.type,
                            id: "\(component.id)_space_\(partIndex)",
                            offset: offset
                        )
                    )
                    partIndex += 1
                    localOffset += whitespace.count
                    localStart = nextIndex
                }
            }
            
            appendPart(from: localStart, to: text.endIndex)
        }
        
        return result
    }
    
    private func handleTap(on component: HighlightComponent) {
        guard !store.isPlaceholder else { return }
        
        let totalLength = max(store.text.count, 1)
        
        let midpoint = component.offset + (component.text.count / 2)
        
        let baseProgress = min(max(Double(midpoint) / Double(totalLength), 0), 1)
        let isNearStart = component.offset < preRollSkipCharacterThreshold
        let progress = isNearStart
        ? baseProgress
        : max(baseProgress - preRollProgressOffset, 0)
        
        store.send(.delegate(.seekToProgress(progress)))
    }
}

private struct HighlightComponent: Identifiable {
    let text: String
    let type: HighlightType
    let id: String
    let offset: Int
    
    enum HighlightType {
        case normal
        case highlighted
        case current
    }
}

private struct FlowLayout: View {
    let components: [HighlightComponent]
    let isInteractionEnabled: Bool
    let onTap: (HighlightComponent) -> Void
    
    var body: some View {
        Text(attributedString)
            .environment(\.openURL, OpenURLAction { url in
                guard isInteractionEnabled,
                      url.scheme == "seek",
                      let targetId = url.host,
                      let component = components.first(where: { $0.id == targetId })
                else { return .systemAction }
                
                onTap(component)
                return .handled
            })
    }
    
    private var attributedString: AttributedString {
        var result = AttributedString()
        
        for component in components {
            var attributed = AttributedString(component.text)
            
            switch component.type {
            case .normal:
                attributed.foregroundColor = .primary
            case .highlighted:
                attributed.foregroundColor = .black
                attributed.backgroundColor = .yellow
            case .current:
                attributed.foregroundColor = .black
                attributed.backgroundColor = .orange
            }
            
            if isInteractionEnabled {
                attributed.link = URL(string: "seek://\(component.id)")
            }
            result += attributed
        }
        
        return result
    }
}

struct LargeScriptTextView: UIViewRepresentable {
    let text: String
    let searchResults: [Range<String.Index>]
    let currentResultIndex: Int
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.backgroundColor = .clear
        textView.alwaysBounceVertical = true
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ]
        )
        
        // 검색 결과 하이라이트 적용
        for (index, range) in searchResults.enumerated() {
            let nsRange = NSRange(range, in: text)
            
            if index == currentResultIndex {
                // 현재 선택된 결과 - 주황색
                attributedString.addAttributes([
                    .backgroundColor: UIColor.orange,
                    .foregroundColor: UIColor.black
                ], range: nsRange)
            } else {
                // 다른 검색 결과 - 노란색
                attributedString.addAttributes([
                    .backgroundColor: UIColor.yellow,
                    .foregroundColor: UIColor.black
                ], range: nsRange)
            }
        }
        
        uiView.attributedText = attributedString
        
        // 현재 결과로 스크롤
        if !searchResults.isEmpty, currentResultIndex < searchResults.count {
            let currentRange = searchResults[currentResultIndex]
            let nsRange = NSRange(currentRange, in: text)
            
            DispatchQueue.main.async {
                uiView.scrollRangeToVisible(nsRange)
            }
        }
    }
}
