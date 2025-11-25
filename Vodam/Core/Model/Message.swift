//
//  ChatData.swift
//  VoDam
//
//  Created by EunYoung Wang on 11/19/25.
//


import FirebaseFirestore
import Foundation

struct Message: Identifiable, Codable,Equatable {
    @DocumentID var id: String?
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    
    init(id: String? = nil, content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}
