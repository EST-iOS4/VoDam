//
//  ProfileImageView.swift
//  Vodam
//
//  Created by 송영민 on 11/24/25.
//

import SwiftUI
import UIKit

// 유저 변경 확인
struct ProfileImageView: View {
    let user: User?
    let size: CGFloat
    let cornerRadius: CGFloat
    let showEditButton: Bool

    @State private var loadedImage: UIImage?

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
        .onChange(of: user?.id) { _, newValue in
                if newValue == nil {
                    loadedImage = nil
                }
            }
    }

    //MARK : 확인 locad에 default 넣기
    @ViewBuilder
    private var imageContent: some View {
        Group {
            if let data = user?.localProfileImageData,
                let uiImage = UIImage(data: data)
            {
                localImage(uiImage)
            } else if let loadedImage {
                localImage(loadedImage)
            } else if user?.profileImageURL != nil {
                ProgressView()
                    .frame(width: size, height: size)
                    .task(id: user?.profileImageURL) {
                        await loadRemoteImage()
                    }
            } else {
                defaultProfileImage
            }
        }
    } /// *

    private func loadRemoteImage() async {
        guard let url = user?.profileImageURL else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let image = UIImage(data: data) {
                loadedImage = image
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("이미지 로드 취소(정상 동작): \(url)")
            } else {
                print("이미지 로드 실패: \(error)")
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
    private var defaultProfileImage: some View {
        if let user, user.provider == .apple {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))

                Text(user.name.isEmpty ? "A" : String(user.name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.gray)
            }
            .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.0, green: 0.5, blue: 1.0))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: size * 0.5))
                        .foregroundColor(.white)
                )
        }
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
