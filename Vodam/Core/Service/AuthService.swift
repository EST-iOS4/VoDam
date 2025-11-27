//
//  AuthService.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import AuthenticationServices
import Dependencies
import Foundation
import GoogleSignIn
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

enum AuthServiceError: Error, Equatable {
    case authError(String)
    case noUser
    case scopeAgreementFailed
    case cancelled
}

enum AuthService {
    
    //MARK: Google 로그인
    static func loginWithGoogle() async throws -> User {
        guard
            let scene = await UIApplication.shared.connectedScenes.first
                as? UIWindowScene,
            let window = await scene.windows.first(where: { $0.isKeyWindow }),
            let rootVC = await window.rootViewController
        else {
            throw AuthServiceError.authError("RootViewController 찾기 실패")
        }
        
        let signInResult = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            DispatchQueue.main.async {
                GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) {
                    result,
                    error in
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
        }
        
        let googleUser = signInResult.user
        
        let name = googleUser.profile?.name ?? "Google User"
        let email = googleUser.profile?.email
        let imageURL = googleUser.profile?.imageURL(withDimension: 200)
        
        return User(
            id: googleUser.userID ?? UUID().uuidString,
            name: name,
            email: email,
            provider: .google,
            profileImageURL: imageURL,
            localProfileImageData: nil
        )
    }
    
    static func loginWithKaKao() async throws -> User {
        // 토큰 확보
        _ = try await kakaoLogin()
        
        // 로그인된 계정 정보 조회
        var kakaoUser = try await fetchKakaoUser()
        
        // 필요한 권한 동의 확인 및 재요청
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
    
    //MARK: 카카오 로그인
    @MainActor
    private static func kakaoLogin() async throws -> OAuthToken {
        return try await withCheckedThrowingContinuation { continuation in
            
            // 중복 resume 방지를 위한 래퍼
            let safeContinuation = SafeContinuation(continuation)
            
            if UserApi.isKakaoTalkLoginAvailable() {
                print("[KakaoAuth] 카카오톡 앱으로 로그인 시도")
                
                UserApi.shared.loginWithKakaoTalk { token, error in
                    if let error = error {
                        print("[KakaoAuth] 카카오톡 로그인 실패: \(error)")
                        
                        // 사용자 취소 체크
                        if let sdkError = error as? SdkError {
                            if case .ClientFailed(let reason, _) = sdkError {
                                if case .Cancelled = reason {
                                    safeContinuation.resume(throwing: AuthServiceError.cancelled)
                                    return
                                }
                            }
                        }
                        
                        // 카카오톡 실패 시 웹 로그인 fallback
                        print("[KakaoAuth] 웹 로그인으로 fallback")
                        UserApi.shared.loginWithKakaoAccount { token, error in
                            if let error = error {
                                print("[KakaoAuth] 웹 로그인도 실패: \(error)")
                                safeContinuation.resume(throwing: AuthServiceError.authError(error.localizedDescription))
                            } else if let token = token {
                                print("[KakaoAuth] 웹 로그인 성공")
                                safeContinuation.resume(returning: token)
                            } else {
                                safeContinuation.resume(throwing: AuthServiceError.noUser)
                            }
                        }
                    } else if let token = token {
                        print("[KakaoAuth] 카카오톡 로그인 성공")
                        safeContinuation.resume(returning: token)
                    } else {
                        safeContinuation.resume(throwing: AuthServiceError.noUser)
                    }
                }
            } else {
                print("[KakaoAuth] 카카오 계정(웹뷰)으로 로그인 시도")
                
                UserApi.shared.loginWithKakaoAccount { token, error in
                    if let error = error {
                        print("[KakaoAuth] 웹뷰 로그인 실패: \(error)")
                        safeContinuation.resume(throwing: AuthServiceError.authError(error.localizedDescription))
                    } else if let token = token {
                        print("[KakaoAuth] 웹뷰 로그인 성공")
                        safeContinuation.resume(returning: token)
                    } else {
                        safeContinuation.resume(throwing: AuthServiceError.noUser)
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
                } else if let user = user {
                    continuation.resume(returning: user)
                } else {
                    continuation.resume(throwing: AuthServiceError.noUser)
                }
            }
        }
    }
    
    //MARK : 로그아웃
    static func logout() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            UserApi.shared.logout { error in
                if let error = error {
                    
                    if let sdkError = error as? SdkError {
                        if case .ClientFailed(let reason, _) = sdkError,
                           case .TokenNotFound = reason
                        {
                            print("카카오 logout: 토큰 없음 → 이미 로그아웃 상태로 처리")
                            continuation.resume(returning: ())
                            return
                        }
                    }
                    print("카카오 logout 실패: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("카카오 logout 성공")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    //MARK : 회원탈퇴
    static func deleteAccount() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            UserApi.shared.unlink { error in
                if let error = error {
                    if let sdkError = error as? SdkError {
                        if case .ClientFailed(let reason, _) = sdkError,
                           case .TokenNotFound = reason
                        {
                            print("카카오 unlink: 토큰 없음 → 이미 탈퇴된 상태로 처리")
                            continuation.resume(returning: ())
                            return
                        }
                    }
                    print("카카오 unlink 실패: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("카카오 unlink 성공")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    //MARK: 닉네임, 프로필 이미지, 이메일 추가 동의
    @MainActor
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
        
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
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

private final class SafeContinuation<T> {
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()
    
    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }
    
    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let cont = continuation else {
            print("[SafeContinuation] ⚠️ 이미 resume됨 - 무시 (returning)")
            return
        }
        continuation = nil
        cont.resume(returning: value)
    }
    
    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let cont = continuation else {
            print("[SafeContinuation] ⚠️ 이미 resume됨 - 무시 (throwing)")
            return
        }
        continuation = nil
        cont.resume(throwing: error)
    }
}

extension AuthService {
    //MARK: Apple 로그인
    static func loginWithApple(userStorageClient: UserStorageClient) async throws -> User {
        guard
            let scene = await UIApplication.shared.connectedScenes.first
                as? UIWindowScene,
            let window = await scene.windows.first(where: { $0.isKeyWindow }),
            let rootVC = await window.rootViewController
        else {
            throw AuthServiceError.authError("RootViewController 찾기 실패")
        }
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [
            request
        ])
        let delegate = await AppleAuthControllerDelegate(
            presentationAnchor: window,
            userStorageClient: userStorageClient
        )
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        
        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            DispatchQueue.main.async {
                controller.performRequests()
            }
        }
    }
    
    static func loginWithApple() async throws -> User {
        @Dependency(\.userStorageClient) var userStorageClient
        return try await loginWithApple(userStorageClient: userStorageClient)
    }
    
    private final class AppleAuthControllerDelegate: NSObject,
                                                     ASAuthorizationControllerDelegate,
                                                     ASAuthorizationControllerPresentationContextProviding
    {
        var continuation: CheckedContinuation<User, Error>?
        private let anchor: ASPresentationAnchor
        private let userStorageClient: UserStorageClient
        
        @MainActor
        init(presentationAnchor: ASPresentationAnchor, userStorageClient: UserStorageClient) {
            self.anchor = presentationAnchor
            self.userStorageClient = userStorageClient
        }
        
        func presentationAnchor(for controller: ASAuthorizationController)
        -> ASPresentationAnchor
        {
            anchor
        }
        
        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            guard
                let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential
            else {
                continuation?.resume(throwing: AuthServiceError.noUser)
                continuation = nil
                return
            }
            
            Task {
                let user = await mapAppleCredentialToUser(credential, userStorageClient: userStorageClient)
                continuation?.resume(returning: user)
                continuation = nil
            }
        }
        
        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: any Error
        ) {
            continuation?.resume(
                throwing: AuthServiceError.authError(error.localizedDescription)
            )
            continuation = nil
        }
        
        private func mapAppleCredentialToUser(
            _ credential: ASAuthorizationAppleIDCredential,
            userStorageClient: UserStorageClient
        ) async -> User {
            let appleUserId = credential.user
            
            let formatter = PersonNameComponentsFormatter()
            let fullName = credential.fullName.flatMap {
                formatter.string(from: $0)
            }
            
            let providedName = (fullName?.isEmpty == false) ? fullName : nil
            let providedEmail = credential.email
            
            var finalName: String
            var finalEmail: String?
            
            if let providedName = providedName {
                finalName = providedName
                finalEmail = providedEmail
                
                await userStorageClient.saveAppleUserInfo(appleUserId, providedName, providedEmail)
                print("[Apple] 최초 로그인 - 이름 저장: \(providedName)")
            }
            else if let stored = await userStorageClient.loadAppleUserInfo(appleUserId) {
                finalName = stored.name
                finalEmail = stored.email
                print("[Apple] 재로그인 - 저장된 이름 사용: \(stored.name)")
            }
            else {
                finalName = "Apple User"
                finalEmail = nil
                print("[Apple] 저장된 정보 없음 - 기본값 사용")
            }
            
            print("[Apple] credential.user:", appleUserId)
            print("[Apple] finalName:", finalName)
            print("[Apple] finalEmail:", finalEmail as Any)
            
            return User(
                appleUserId: appleUserId,
                id: appleUserId,
                name: finalName,
                email: finalEmail,
                provider: .apple,
                profileImageURL: nil,
                localProfileImageData: nil
            )
        }
    }
}
