    //
    //  AppConfig.swift
    //  Vodam
    //
    //  Created by EunYoung Wang on 11/18/25.
    //

import SwiftUI

enum AppConfig {
        // MARK: - 폰트
    static func PretendardBlack(size: CGFloat) -> Font {
        Font.custom("Pretendard-Black", size: size)
    }
    static func pretendardBold(size: CGFloat) -> Font {
        Font.custom("Pretendard-Bold", size: size)
    }
    static func pretendardExtraBold(size: CGFloat) -> Font {
        Font.custom("Pretendard-ExtraBold", size: size)
    }
    static func pretendardExtraLight(size: CGFloat) -> Font {
        Font.custom("Pretendard-ExtraLight", size: size)
    }
    static func pretendardLight(size: CGFloat) -> Font {
        Font.custom("Pretendard-Light", size: size)
    }
    static func pretendardMedium(size: CGFloat) -> Font {
        Font.custom("Pretendard-Medium", size: size)
    }
    static func pretendardRegular(size: CGFloat) -> Font {
        Font.custom("Pretendard-Regular", size: size)
    }
    static func pretendardSemiBold(size: CGFloat) -> Font {
        Font.custom("Pretendard-SemiBold", size: size)
    }
    static func pretendardThin(size: CGFloat) -> Font {
        Font.custom("Pretendard-Thin", size: size)
    }
    
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
