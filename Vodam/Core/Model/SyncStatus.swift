//
//  SyncStatus.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import Foundation

enum SyncStatus: String, Codable, Sendable {
    case localOnly 
    case synced
    case deleted
}
