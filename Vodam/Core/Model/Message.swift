//
//  ChatData.swift
//  VoDam
//
//  Created by EunYoung Wang on 11/19/25.
//


import FirebaseFirestoreSwift
import Foundation

@Model
final class Message {
    var id: UUID
        // 메세지 내용(text)
    var content: String
        // 메세지 발신자 (False = AI, True = 사용자)
    var isFromUser: Bool
    var timestamp: Date
    
        // 메세지 인스턴스 초기화
    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
    }
}
