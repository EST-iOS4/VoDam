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
    
    var formattedDate: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yy/MM/dd a h:mm"
            return formatter.string(from: recentEditedDate)
        }
}
