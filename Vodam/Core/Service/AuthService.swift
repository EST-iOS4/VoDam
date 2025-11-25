//
//  AuthService.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import Foundation
import KakaoSDKAuth
import KakaoSDKUser
import GoogleSignIn

enum AuthServiceError: Error, Equatable {
    case authError(String)
    case noUser
    case scopeAgreementFailed
}

enum AuthService {
    
    //MARK: Google 로그인
    static func loginWithGoogle() async throws -> User {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            let rootVC = window.rootViewController
        else {
            throw AuthServiceError.authError("구글 로그인 실패")
        }
        
        let signInResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result = result else {
                    continuation.resume(throwing: AuthServiceError.noUser)
                    return
                }
                continuation.resume(returning: result)
            }
        }
        
        let googleUser = signInResult.user
        
        let name = googleUser.profile?.name ?? "Google User"
        let email = googleUser.profile?.email
        let imageURL = googleUser.profile?.imageURL(withDimension: 200)
        
        return User (
            id: googleUser.userID ?? UUID().uuidString,
            name: name,
            email: email,
            provider: .google,
            profileImageURL: imageURL,
            localProfileImageData: nil
        )
    }
    
    //MARK: 카카오 로그인
    static func loginWithKaKao() async throws -> User {
        //로그인 해서 토큰 확보
        _ = try await kakaoLogin()
        
        // 로그인된 계정 정보 조회
        var kakaoUser = try await fetchKakaoUser()
        
        //필요한 권한 동의 확인 및 재요청 (닉네임, 이메일, 프로필 이미지 등)
        kakaoUser = try await ensureKakaoScopesIfNeeded(kakaoUser)
        
        let account = kakaoUser.kakaoAccount
        let profile = account?.profile
        
        let name = profile?.nickname ?? "이름 없음"
        let email = account?.email 
        let profileURL = profile?.profileImageUrl
        let kakaoIdString = kakaoUser.id.map { String($0) } ?? UUID().uuidString
        
        return User(
            id: kakaoIdString,
            name: name,
            email: email,
            provider: .kakao,
            profileImageURL: profileURL,
            localProfileImageData: nil
        )
    }
    
    //MARK: - 실제 kakao 로그인
        private static func kakaoLogin() async throws -> OAuthToken {
            return try await withCheckedThrowingContinuation { continuation in
                if UserApi.isKakaoTalkLoginAvailable() {
                    //카카오톡 앱으로 로그인
                    UserApi.shared.loginWithKakaoTalk() { token, error in
                        if let error = error {
                            continuation.resume(
                                throwing: AuthServiceError.authError(
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
                                throwing: AuthServiceError.authError(
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
    
    //MARK: 사용자 정보 가져오기
    private static func fetchKakaoUser() async throws -> KakaoSDKUser.User {
        try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.me { user, error in
                if let error = error {
                    continuation.resume(
                        throwing: AuthServiceError.authError(
                            error.localizedDescription
                        )
                    )
                }else if let user = user {
                    continuation.resume(returning: user)
                } else {
                    continuation.resume(throwing: AuthServiceError.noUser)
                }
            }
        }
    }
    
    //MARK : 로그아웃
    static func logout() async throws {
        try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<Void, Error>) in
            UserApi.shared.logout{ error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    //MARK : 회원탈퇴
    static func deleteAccount() async throws {
        try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<Void, Error>) in
            UserApi.shared.unlink{ error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    //MARK: 닉네임, 프로필 이미지, 이메일 추가 동의
    private static func ensureKakaoScopesIfNeeded(_ user: KakaoSDKUser.User)
    async throws -> KakaoSDKUser.User
    {
        guard let account = user.kakaoAccount else {
            return user
        }
        
        var scopes: [String] = []
        
        if account.profileNeedsAgreement ?? false {
            scopes.append("profile_nickname")
            scopes.append("profile_image")
        }
        
        if account.emailNeedsAgreement ?? false {
            scopes.append("account_email")
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

