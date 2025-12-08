//
//  Extension+Int.swift
//  Vodam
//
//  Created by 이건준 on 11/24/25.
//

import Foundation

extension Int {
    var formattedTime: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
