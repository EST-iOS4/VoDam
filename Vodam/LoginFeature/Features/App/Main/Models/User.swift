//
//  User.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import Foundation

enum AuthProvider: Equatable, Codable {
    case apple
    case google
    case kakao
}

struct User: Equatable, Codable {
    var name: String
    var email: String?
    var provider: AuthProvider
    var profileImageURL: URL?

    static let placeholder = User(
        name: "Vodam",
        email: nil,
        provider: .kakao,
        profileImageURL: nil
    )
}
