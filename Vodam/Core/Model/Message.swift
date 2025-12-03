//
//  ChatData.swift
//  VoDam
//
//  Created by EunYoung Wang on 11/19/25.
//

import Foundation

struct Message: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    
    var uniqueId: String { id }
    
    init(
        id: String = UUID().uuidString,
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isFromUser == rhs.isFromUser
    }
}
