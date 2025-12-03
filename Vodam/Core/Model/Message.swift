//
//  ChatData.swift
//  VoDam
//
//  Created by EunYoung Wang on 11/19/25.
//


import FirebaseFirestore
import Foundation

struct Message: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    
    var uniqueId: String { id }
    
    init(id: String = UUID().uuidString, content: String, isFromUser: Bool, timestamp: Date = Date()) {
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case isFromUser
        case timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let decodedId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = decodedId
        } else {
            id = UUID().uuidString
        }
        
        content = try container.decode(String.self, forKey: .content)
        
        if let boolValue = try? container.decode(Bool.self, forKey: .isFromUser) {
            isFromUser = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isFromUser) {
            isFromUser = intValue != 0
        } else {
            isFromUser = false
        }
        
        if let firestoreTimestamp = try? container.decode(Timestamp.self, forKey: .timestamp) {
            timestamp = firestoreTimestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else {
            timestamp = Date()
        }
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let content = data["content"] as? String else {
            return nil
        }
        
        let isFromUser: Bool
        if let boolValue = data["isFromUser"] as? Bool {
            isFromUser = boolValue
        } else if let intValue = data["isFromUser"] as? Int {
            isFromUser = intValue != 0
        } else {
            isFromUser = false
        }
        
        let timestamp: Date
        if let firestoreTimestamp = data["timestamp"] as? Timestamp {
            timestamp = firestoreTimestamp.dateValue()
        } else if let date = data["timestamp"] as? Date {
            timestamp = date
        } else {
            timestamp = Date()
        }
        
        self.init(
            id: document.documentID,
            content: content,
            isFromUser: isFromUser,
            timestamp: timestamp
        )
    }
}
