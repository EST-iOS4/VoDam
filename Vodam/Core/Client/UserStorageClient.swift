//
//  UserStorageClient.swift
//  Vodam
//
//  Created by 송영민 on 11/25/25.
//

import Dependencies
import Foundation

struct UserStorageClient: Sendable {
    var load: @Sendable () async -> User?
    var save: @Sendable (User?) async -> Void
    var clear: @Sendable () async -> Void
}

extension UserStorageClient: DependencyKey {
    static var liveValue: UserStorageClient {
        let key = "currentUser"

        return .init(
            load: {
                await MainActor.run {
                    guard
                        let data = UserDefaults.standard.data(forKey: key)
                    else {
                        return nil
                    }
                    
                    do {
                        let user = try JSONDecoder().decode(User.self, from: data)
                        return user
                    } catch {
                        print("UserStorage 디코딩 실패: \(error)")
                        return nil
                    }
                }
            },
            save: { user in
                await MainActor.run {
                    let defaults = UserDefaults.standard
                    
                    guard let user else {
                        defaults.removeObject(forKey: key)
                        return
                    }
                    
                    do {
                        let data = try JSONEncoder().encode(user)
                        defaults.set(data, forKey: key)
                    } catch {
                        print("UserStorage 인코딩 실패: \(error)")
                    }
                }
            },
            clear: {
                UserDefaults.standard.removeObject(forKey: key)
            }
        )
    }

    static var testValue: UserStorageClient {
        let storage = UserStorageActor()

        return .init(
            load: {
                await storage.getUser()
            },
            save: { user in
                await storage.setUser(user)
            },
            clear: {
                await storage.clear()
            }
        )
    }
}

// 테스트용 Actor
private actor UserStorageActor {
    private var storedUser: User?

    func getUser() -> User? {
        return storedUser
    }

    func setUser(_ user: User?) {
        storedUser = user
    }

    func clear() {
        storedUser = nil
    }
}

extension DependencyValues {
    var userStorageClient: UserStorageClient {
        get { self[UserStorageClient.self] }
        set { self[UserStorageClient.self] = newValue }
    }
}
