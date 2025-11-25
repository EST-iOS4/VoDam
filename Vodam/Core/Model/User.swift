//
//  User.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import Foundation

enum AuthProvider: Equatable, Codable, Sendable {
    case apple
    case google
    case kakao
}

struct User: Equatable, Codable, Identifiable, Sendable {
    var id:String
    var name: String
    var email: String?
    var provider: AuthProvider
    var profileImageURL: URL?
    var localProfileImageData: Data?

    static let placeholder = User(
        id: "placeholder",
        name: "Vodam",
        email: nil,
        provider: .kakao,
        profileImageURL: nil,
        localProfileImageData: nil
    )
}
