//
//  Category.swift
//  Vodam
//
//  Created by 서정원 on 11/18/25.
//

import Foundation


enum ProjectCategory: String, Codable, CaseIterable, Hashable {
    case audio
    case file
    case pdf

    var title: String {
        switch self {
        case .audio: return "녹음"
        case .file: return "파일"
        case .pdf: return "PDF"
        }
    }
}

nonisolated
enum FilterCategory: Hashable, CaseIterable {
    case all
    case project(ProjectCategory)
    
    var title: String {
        switch self {
        case .all:
            return "전체" // <-- 문제의 레이블 제거
        case .project(let category):
            return category.title
        }
    }

    static var allCases: [FilterCategory] {
        return [.all] + ProjectCategory.allCases.map { .project($0) }
    }

    var projectCategory: ProjectCategory? {
        if case .project(let category) = self {
            return category
        }
        return nil
    }
}
