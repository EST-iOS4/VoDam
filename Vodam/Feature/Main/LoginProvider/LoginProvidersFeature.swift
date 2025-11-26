//
//  LoginProvidersFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//
import ComposableArchitecture
import Foundation

@Reducer
struct LoginProvidersFeature {

    @ObservableState
    struct State: Equatable {
    }

    enum Provider: Equatable {
        case apple
        case google
        case kakao
    }

    enum LoginError: Error {
        case notImplemented(String)
    }

    enum Action: Equatable {
        case providerTapped(Provider)

        enum Delegate: Equatable {
            case login(Bool, User?)
        }
        case delegate(Delegate)
    }

    @Dependency(\.kakaoAuthClient) var kakaoAuthClient
    @Dependency(\.googleAuthClient) var googleAuthClient
    @Dependency(\.appleAuthClient) var appleAuthClient
    @Dependency(\.userStorageClient) var userStorageClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .providerTapped(let provider):
                return .run {
                    [
                        userStorageClient, kakaoAuthClient, appleAuthClient,
                        googleAuthClient
                    ] send in
                    do {
                        let rawUser: User

                        switch provider {
                        case .kakao:
                            rawUser = try await kakaoAuthClient.login()

                        case .apple:
                            rawUser = try await appleAuthClient.login()

                        case .google:
                            rawUser = try await googleAuthClient.login()
                        }

                        print("🧩 [LoginProviders] provider:", provider)
                        print("🧩 [LoginProviders] rawUser:", rawUser)

                        let storedUser = await userStorageClient.load()
                        print(
                            "🧩 [LoginProviders] storedUser:",
                            storedUser as Any
                        )

                        let finalUser: User

                        if provider == .apple, let stored = storedUser,
                            stored.ownerId == rawUser.ownerId
                        {
                            print(
                                "🧩 [LoginProviders] use storedUser (same ownerId)"
                            )
                            finalUser = stored
                        } else {
                            print("🧩 [LoginProviders] use rawUser")
                            finalUser = rawUser
                        }

                        print("🧩 [LoginProviders] finalUser:", finalUser)

                        await userStorageClient.save(finalUser)

                        await send(.delegate(.login(true, finalUser)))

                    } catch {
                        print("로그인 실패: \(error)")
                        await send(.delegate(.login(false, nil)))
                    }

                }
            case .delegate:
                return .none
            }
        }
    }
}
