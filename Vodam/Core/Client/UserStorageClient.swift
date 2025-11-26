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
                    let defaults = UserDefaults.standard
                    guard let data = defaults.data(forKey: key) else {
                        print("🟡 [UserStorage] load: no stored user")
                        return nil
                    }
                    do {
                        let user = try JSONDecoder().decode(
                            User.self,
                            from: data
                        )
                        print("🟡 [UserStorage] load:", user)
                        return user
                    } catch {
                        print("🟡 [UserStorage] load decode error:", error)
                        return nil
                    }
                }
            },
            save: { user in
                let defaults = UserDefaults.standard
                if let user {
                    do {
                        let data = try JSONEncoder().encode(user)
                        defaults.set(data, forKey: key)
                        print("🟢 [UserStorage] save:", user)
                    } catch {
                        print("🟢 [UserStorage] save encode error:", error)
                    }
                } else {
                    defaults.removeObject(forKey: key)
                    print("🟢 [UserStorage] save(nil) → removed")
                }
            },
            clear: {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: key)
                print("🧹 [UserStorage] clear called")
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
