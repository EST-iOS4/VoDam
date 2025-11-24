//
//  SortFilter.swift
//  Vodam
//
//  Created by 서정원 on 11/18/25.
//

import Foundation

enum SortFilter: String, CaseIterable {
    case sortedName
    case sortedDate
    
    var title: String {
        switch self {
        case .sortedDate: return "생성일 순"
        case .sortedName: return "이름 순"
        }
    }
}
