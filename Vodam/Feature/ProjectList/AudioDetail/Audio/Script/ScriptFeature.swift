//
//  ScriptFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ScriptFeature {
    @ObservableState
    struct State: Equatable {
        var text: String
        var searchText: String = ""
        var searchResults: [Range<String.Index>] = []
        var currentResultIndex: Int = 0
        
        var totalResults: Int {
            searchResults.count
        }
        
        var currentResultNumber: Int {
            guard !searchResults.isEmpty else { return 0 }
            return currentResultIndex + 1
        }
        
        var isPlaceholder: Bool {
            text == ScriptFeature.placeholderText
        }
        
        init(text: String = "This is the script content.") {
            self.text = text
        }
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.text == rhs.text &&
            lhs.searchText == rhs.searchText &&
            lhs.currentResultIndex == rhs.currentResultIndex &&
            lhs.totalResults == rhs.totalResults
        }
    }
    
    static let placeholderText = "아직 받아온 스크립트가 없습니다."

    enum Action {
        case setText(String)
        case search(String)
        case clearSearch
        case nextResult
        case previousResult
        case delegate(DelegateAction)
        
        enum DelegateAction {
            case seekToProgress(Double)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setText(let text):
                state.text = text
                return .none
                
            case .search(let query):
                state.searchText = query
                state.searchResults = []
                state.currentResultIndex = 0
                
                guard !query.isEmpty else { return .none }
                
                let text = state.text
                let searchQuery = query.lowercased()
                var results: [Range<String.Index>] = []
                var searchStartIndex = text.startIndex
                
                while searchStartIndex < text.endIndex {
                    let searchRange = searchStartIndex..<text.endIndex
                    if let range = text.range(of: searchQuery, options: .caseInsensitive, range: searchRange) {
                        results.append(range)
                        searchStartIndex = range.upperBound
                    } else {
                        break
                    }
                }
                
                state.searchResults = results
                print("[Script] 검색 결과: \(results.count)개")
                return .none
                
            case .clearSearch:
                state.searchText = ""
                state.searchResults = []
                state.currentResultIndex = 0
                return .none
                
            case .nextResult:
                guard !state.searchResults.isEmpty else { return .none }
                state.currentResultIndex = (state.currentResultIndex + 1) % state.searchResults.count
                return .none
                
            case .previousResult:
                guard !state.searchResults.isEmpty else { return .none }
                state.currentResultIndex = (state.currentResultIndex - 1 + state.searchResults.count) % state.searchResults.count
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}
