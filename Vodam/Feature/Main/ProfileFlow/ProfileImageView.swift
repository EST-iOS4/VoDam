//
//  ProfileImageView.swift
//  Vodam
//
//  Created by 송영민 on 11/24/25.
//

import SwiftUI
import UIKit

struct ProfileImageView: View {
    let user: User?
    let size: CGFloat
    let cornerRadius: CGFloat
    let showEditButton: Bool
    
    init(
        user: User?,
        size: CGFloat = 80,
        cornerRadius: CGFloat = 24,
        showEditButton: Bool = false
    ) {
        self.user = user
        self.size = size
        self.cornerRadius = cornerRadius
        self.showEditButton = showEditButton
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            imageContent
            
            if showEditButton && user != nil {
                editButton
            }
        }
    }
    
    @ViewBuilder
    private var imageContent: some View {
        Group {
            if let data = user?.localProfileImageData,
               let uiImage = UIImage(data: data) {
                localImage(uiImage)
            } else if let url = user?.profileImageURL {
                remoteImage(url)
            } else {
                defaultProfileImage
            }
        }
    }

    @ViewBuilder
    private func localImage(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private func remoteImage(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            asyncImageContent(phase)
        }
    }

    @ViewBuilder
    private func asyncImageContent(_ phase: AsyncImagePhase) -> some View {
        switch phase {
        case .empty:
            ProgressView()
                .frame(width: size, height: size)
//                .onAppear {
//                    print("이미지 로딩")
//                }
        case .success(let image):
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
//                .onAppear {
//                    print("이미지 성공")
//                }
            
        case .failure:
            defaultProfileImage
//                .onAppear {
//                    print("이미지 실패")
//                }
        
        @unknown default:
            defaultProfileImage
        }
    }
    
    private var defaultProfileImage: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(red: 0.0, green: 0.5, blue: 1.0))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            )
    }
    
    private var editButton: some View {
        Circle()
            .fill(Color.black)
            .frame(width: size * 0.375, height: size * 0.375)
            .overlay(
                Image(systemName: "pencil")
                    .font(.system(size: size * 0.3125))
                    .foregroundColor(.white)
            )
    }
}
