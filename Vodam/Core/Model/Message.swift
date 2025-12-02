    //
    //  ChatData.swift
    //  VoDam
    //
    //  Created by EunYoung Wang on 11/19/25.
    //


import FirebaseFirestore
import Foundation

struct Message: Identifiable, Codable,Equatable {
    var id: String?
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    
    var localId: String {
        return id ?? UUID().uuidString
    }
    
    var uniqueId: String {
        return id ?? UUID().uuidString
    }
    
    init(id: String? = nil, content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        
            // Bool 또는 Int 처리
        if let boolValue = try? container.decode(Bool.self, forKey: .isFromUser) {
            isFromUser = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isFromUser) {
            isFromUser = intValue != 0 //1이면 true
        } else {
            isFromUser = false
        }
        
            // Timestamp 처리
        if let firestoreTimestamp = try? container.decode(Timestamp.self, forKey: .timestamp) {
            timestamp = firestoreTimestamp.dateValue()
        } else if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else {
            timestamp = Date()
        }
    }
}
