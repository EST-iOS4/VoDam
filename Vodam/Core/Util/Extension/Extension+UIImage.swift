//
//  Extension+UIImage.swift
//  Vodam
//
//  Created by 송영민 on 11/24/25.
//

import UIKit

extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(
            width: width,
            height: CGFloat(ceil(width / size.width * size.height))
        )
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
