//
//  ChattingInfo.swift
//  Vodam
//
//  Created by 이건준 on 11/24/25.
//

import Foundation

struct ChattingInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let content: String
    let recentEditedDate: Date
}
