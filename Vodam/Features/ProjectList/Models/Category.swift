//
//  Category.swift
//  Vodam
//
//  Created by 서정원 on 11/18/25.
//

import Foundation

enum Category: String, Encodable, CaseIterable {
    case all
    case audio
    case file
    case pdf
    
    var title: String {
        switch self {
        case .all: return "전체"
        case .audio: return "녹음"
        case .file: return "파일"
        case .pdf: return "PDF"
        }
    }
}
