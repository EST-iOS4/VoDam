//
//  ScriptView.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

struct ScriptView: View {
    let store: StoreOf<ScriptFeature>
    
    var body: some View {
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
        if store.searchText.isEmpty || store.searchResults.isEmpty {
            Text(store.text)
                .foregroundColor(.primary)
        } else {
            highlightedContentView
        }
    }
    
    @ViewBuilder
    private var highlightedContentView: some View {
        let components = buildHighlightComponents(
            text: store.text,
            results: store.searchResults,
            currentIndex: store.currentResultIndex
        )
        
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(components: components)
        }
    }
    
    private func buildHighlightComponents(
        text: String,
        results: [Range<String.Index>],
        currentIndex: Int
    ) -> [HighlightComponent] {
        var components: [HighlightComponent] = []
        var lastEndIndex = text.startIndex
        
        for (index, range) in results.enumerated() {
            if lastEndIndex < range.lowerBound {
                let normalText = String(text[lastEndIndex..<range.lowerBound])
                components.append(HighlightComponent(
                    text: normalText,
                    type: .normal,
                    id: "normal_\(index)"
                ))
            }
            
            let highlightedText = String(text[range])
            let isCurrent = index == currentIndex
            components.append(HighlightComponent(
                text: highlightedText,
                type: isCurrent ? .current : .highlighted,
                id: "result_\(index)"
            ))
            
            lastEndIndex = range.upperBound
        }
        
        if lastEndIndex < text.endIndex {
            let remainingText = String(text[lastEndIndex..<text.endIndex])
            components.append(HighlightComponent(
                text: remainingText,
                type: .normal,
                id: "remaining"
            ))
        }
        
        return components
    }
}

private struct HighlightComponent: Identifiable {
    let text: String
    let type: HighlightType
    let id: String
    
    enum HighlightType {
        case normal
        case highlighted
        case current
    }
}

private struct FlowLayout: View {
    let components: [HighlightComponent]
    
    var body: some View {
        Text(attributedString)
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
            
            result += attributed
        }
        
        return result
    }
}
