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
        
        var body: some View {
            ScriptTextView(
                text: store.text,
                searchResults: store.searchResults,
                currentResultIndex: store.currentResultIndex,
                isPlaceholder: store.isPlaceholder,
                onTap: { progress in
                    store.send(.delegate(.seekToProgress(progress)))
                }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - UIKit TextView

    struct ScriptTextView: UIViewRepresentable {
        let text: String
        let searchResults: [Range<String.Index>]
        let currentResultIndex: Int
        let isPlaceholder: Bool
        let onTap: (Double) -> Void
        
        func makeCoordinator() -> Coordinator {
            Coordinator(onTap: onTap, text: text)
        }
        
        func makeUIView(context: Context) -> UITextView {
            let textView = UITextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.isScrollEnabled = true
            textView.showsVerticalScrollIndicator = true
            textView.showsHorizontalScrollIndicator = false
            textView.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
            textView.backgroundColor = UIColor.secondarySystemBackground
            textView.layer.cornerRadius = 16
            textView.clipsToBounds = true
            textView.alwaysBounceVertical = true
            
            // 탭 제스처 추가
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            tapGesture.delegate = context.coordinator
            textView.addGestureRecognizer(tapGesture)
            
            context.coordinator.textView = textView
            
            return textView
        }
        
        func updateUIView(_ uiView: UITextView, context: Context) {
            // Coordinator 업데이트
            context.coordinator.text = text
            
            // 텍스트 또는 검색 결과가 변경되었는지 확인
            let textChanged = context.coordinator.lastText != text
            let searchResultsChanged = context.coordinator.lastSearchResultsCount != searchResults.count
            let indexChanged = context.coordinator.lastResultIndex != currentResultIndex
            
            // AttributedString 생성 및 적용
            if textChanged || searchResultsChanged || indexChanged {
                let attributedString = createAttributedString()
                uiView.attributedText = attributedString
                context.coordinator.lastText = text
                context.coordinator.lastSearchResultsCount = searchResults.count
            }
            
            // currentResultIndex가 변경된 경우에만 스크롤
            if indexChanged && !searchResults.isEmpty {
                context.coordinator.lastResultIndex = currentResultIndex
                scrollToCurrentResult(uiView, context: context)
            }
        }
        
        private func createAttributedString() -> NSAttributedString {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            
            let attributedString = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: UIFont(name: "Pretendard-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17),
                    .foregroundColor: isPlaceholder ? UIColor.secondaryLabel : UIColor.label,
                    .paragraphStyle: paragraphStyle
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
            
            return attributedString
        }
        
        private func scrollToCurrentResult(_ textView: UITextView, context: Context) {
            guard !searchResults.isEmpty, currentResultIndex >= 0, currentResultIndex < searchResults.count else { return }
            
            let currentRange = searchResults[currentResultIndex]
            let nsRange = NSRange(currentRange, in: text)
            
            // 레이아웃 완료 후 스크롤 실행
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 해당 범위의 rect 계산
                guard let start = textView.position(from: textView.beginningOfDocument, offset: nsRange.location),
                      let end = textView.position(from: start, offset: nsRange.length),
                      let textRange = textView.textRange(from: start, to: end) else {
                    print("❌ 스크롤 실패: 텍스트 범위를 찾을 수 없음")
                    return
                }
                
                let rect = textView.firstRect(for: textRange)
                
                // rect가 유효한지 확인
                guard !rect.isNull && !rect.isInfinite && rect.origin.y >= 0 else {
                    print("❌ 스크롤 실패: 유효하지 않은 rect - \(rect)")
                    return
                }
                
                // 상단 여백 (검색창 + 탭바 높이 고려)
                let topInset: CGFloat = 120
                // 하단 여백 (PDF 정보 섹션 또는 오디오 플레이어 높이 고려)
                let bottomInset: CGFloat = 250
                
                let visibleHeight = textView.bounds.height - topInset - bottomInset
                
                // 하이라이트가 보이는 영역의 중앙에 오도록 계산
                let targetY = rect.origin.y - topInset - (visibleHeight / 2) + (rect.height / 2)
                let maxY = max(0, textView.contentSize.height - textView.bounds.height)
                let clampedY = max(0, min(targetY, maxY))
                
                print("✅ 스크롤: index=\(self.currentResultIndex), rect.y=\(rect.origin.y), targetY=\(clampedY)")
                
                textView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: true)
            }
        }
        
        // MARK: - Coordinator
        
        class Coordinator: NSObject, UIGestureRecognizerDelegate {
            weak var textView: UITextView?
            var text: String
            let onTap: (Double) -> Void
            
            // 변경 감지용
            var lastResultIndex: Int = -1
            var lastText: String = ""
            var lastSearchResultsCount: Int = 0
            
            private let preRollProgressOffset: Double = 0.01
            private let preRollSkipCharacterThreshold: Int = 5
            
            init(onTap: @escaping (Double) -> Void, text: String) {
                self.onTap = onTap
                self.text = text
            }
            
            @objc func handleTap(_ gesture: UITapGestureRecognizer) {
                guard let textView = textView else { return }
                
                let location = gesture.location(in: textView)
                
                // 텍스트 영역 내인지 확인
                let textContainerOffset = CGPoint(
                    x: location.x - textView.textContainerInset.left,
                    y: location.y - textView.textContainerInset.top
                )
                
                let layoutManager = textView.layoutManager
                let textContainer = textView.textContainer
                
                // 탭한 위치의 문자 인덱스
                let characterIndex = layoutManager.characterIndex(
                    for: textContainerOffset,
                    in: textContainer,
                    fractionOfDistanceBetweenInsertionPoints: nil
                )
                
                guard characterIndex < text.count else { return }
                
                // 진행률 계산
                let totalLength = max(text.count, 1)
                let baseProgress = min(max(Double(characterIndex) / Double(totalLength), 0), 1)
                let isNearStart = characterIndex < preRollSkipCharacterThreshold
                let progress = isNearStart ? baseProgress : max(baseProgress - preRollProgressOffset, 0)
                
                onTap(progress)
            }
            
            // 텍스트 선택과 탭 제스처 공존을 위해
            func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
                return true
            }
        }
    }
