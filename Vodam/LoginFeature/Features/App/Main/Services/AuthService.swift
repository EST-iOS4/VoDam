//
//  AuthService.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import Foundation
import KakaoSDKAuth
import KakaoSDKUser

enum AuthServiceError: Error, Equatable {
    case kakaoError(String)
    case noUser
}

enum AuthService {
    //카카오 로그인 + 사용자 정보 가져오기
    static func loginWithKaKao() async throws -> User {
        //로그인 해서 토큰 확보
        _ = try await kakaoLogin()

        // 로그인된 계정 정보 조회
        var kakaoUser = try await fetchKakaoUser()

        kakaoUser = try await ensureKakaoScopesIfNeeded(kakaoUser)

        let account = kakaoUser.kakaoAccount
        let profile = account?.profile

        let name = profile?.nickname ?? "이름 없음"
        //프로필 이미지 URL
        let email = account?.email
        let profileURL = profile?.profileImageUrl

        //이메일은 못가져오고,
        return User(
            name: name,
            email: email,
            provider: .kakao,
            profileImageURL: profileURL
        )
    }

    //MARK: - 실제 kakao 로그인
    private static func kakaoLogin() async throws -> OAuthToken {
        return try await withCheckedThrowingContinuation { continuation in
            if UserApi.isKakaoTalkLoginAvailable() {
                //카카오톡 앱으로 로그인
                UserApi.shared.loginWithKakaoTalk { token, error in
                    if let error = error {
                        continuation.resume(
                            throwing: AuthServiceError.kakaoError(
                                error.localizedDescription
                            )
                        )
                    } else if let token = token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: AuthServiceError.noUser)
                    }
                }
            } else {
                //카카오 계정 (웹뷰)으로 로그인
                UserApi.shared.loginWithKakaoAccount { token, error in
                    if let error = error {
                        continuation.resume(
                            throwing: AuthServiceError.kakaoError(
                                error.localizedDescription
                            )
                        )
                    } else if let token = token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: AuthServiceError.noUser)
                    }
                }
            }
        }
    }

    //MARK: 이미지 같은 거 추가 동의
    private static func ensureKakaoScopesIfNeeded(_ user: KakaoSDKUser.User)
        async throws -> KakaoSDKUser.User
    {
        guard let account = user.kakaoAccount else {
            return user
        }

        var scopes: [String] = []

        if account.profileNeedsAgreement == true {
            scopes.append("profile")
        }
        
        if scopes.isEmpty {
            return user
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UserApi.shared.loginWithKakaoAccount(scopes: scopes) { _, error in
                if let error = error {
                        continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        let updateUser = try await fetchKakaoUser()
        return updateUser
    }
}

private func fetchKakaoUser() async throws -> KakaoSDKUser.User {
    try await withCheckedThrowingContinuation { continuation in
        UserApi.shared.me { user, error in
            if let error = error {
                continuation.resume(
                    throwing: AuthServiceError.kakaoError(
                        error.localizedDescription
                    )
                )
            } else if let user = user {
                continuation.resume(returning: user)
            } else {
                continuation.resume(throwing: AuthServiceError.noUser)
            }
        }
    }
}
