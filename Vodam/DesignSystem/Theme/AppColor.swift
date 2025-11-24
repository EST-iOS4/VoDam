//
//  AppColor.swift
//  Vodam
//
//  Created by 이건준 on 11/24/25.
//

import SwiftUI

enum AppColor{
        // MARK: - 색상
    static let mainColor = Color(hex: "#6032dd")
}

    // MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
            case 6: // RGB
                (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
            default:
                (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
