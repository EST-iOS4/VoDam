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

    nonisolated enum Provider: Equatable, Sendable {
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
    @Dependency(\.firebaseClient) var firebaseClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .providerTapped(let provider):
                return .run { [
                    userStorageClient,
                    kakaoAuthClient,
                    appleAuthClient,
                    googleAuthClient,
                    firebaseClient
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

                        print("[LoginProviders] provider:", provider)
                        print("[LoginProviders] rawUser:", rawUser)

                        let storedUser = await userStorageClient.load()
                        print("[LoginProviders] storedUser:", storedUser as Any)


                        let baseUser: User
                        if provider == .apple,
                           let stored = storedUser,
                           stored.ownerId == rawUser.ownerId {
                            print("[LoginProviders] use storedUser (same ownerId) as base")
                            baseUser = stored
                        } else {
                            print("[LoginProviders] use rawUser as base")
                            baseUser = rawUser
                        }

                        let finalUser: User
                        if provider == .apple {
                            if let remote = try await firebaseClient.fetchUserProfile(baseUser.ownerId) {
                                print("[LoginProviders] fetched remote user profile:", remote)
                                var merged = remote
                                if let localData = baseUser.localProfileImageData {
                                    merged.localProfileImageData = localData
                                }

                                finalUser = try await firebaseClient.upsertUserProfile(merged)
                            } else {
                                print("[LoginProviders] no remote user profile, create new one")
                                finalUser = try await firebaseClient.upsertUserProfile(baseUser)
                            }
                        } else {
                            finalUser = baseUser
                        }

                        print("[LoginProviders] finalUser (after Firebase sync):", finalUser)

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
