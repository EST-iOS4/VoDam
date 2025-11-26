//
//  Tab.swift
//  Vodam
//
//  Created by seojeong-won on 11/24/25.
//

import Foundation

nonisolated
enum Tab: CaseIterable {
    case aiSummary
    case script
    
    var title: String {
        switch self {
        case .aiSummary:
            return "AI 요약"
        case .script:
            return "스크립트"
        }
    }
}
