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
    
    var loadAppleUserInfo: @Sendable (_ appleUserId: String) async -> (name: String, email: String?)?
    var saveAppleUserInfo: @Sendable (_ appleUserId: String, _ name: String, _ email: String?) async -> Void
}

extension UserStorageClient: DependencyKey {
    static var liveValue: UserStorageClient {
        let currentUserKey = "currentUser"
        let appleUsersKey = "appleUserInfo"
        
        return .init(
            load: {
                await MainActor.run {
                    let defaults = UserDefaults.standard
                    guard let data = defaults.data(forKey: currentUserKey) else {
                        print("[UserStorage] load: no stored user")
                        return nil
                    }
                    do {
                        let user = try JSONDecoder().decode(
                            User.self,
                            from: data
                        )
                        print("[UserStorage] load:", user)
                        return user
                    } catch {
                        print("[UserStorage] load decode error:", error)
                        return nil
                    }
                }
            },
            save: { user in
                let defaults = UserDefaults.standard
                if let user {
                    do {
                        let data = try JSONEncoder().encode(user)
                        defaults.set(data, forKey: currentUserKey)
                        print("[UserStorage] save:", user)
                    } catch {
                        print("[UserStorage] save encode error:", error)
                    }
                } else {
                    defaults.removeObject(forKey: currentUserKey)
                    print("[UserStorage] save(nil) → removed")
                }
            },
            clear: {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: currentUserKey)
                print("[UserStorage] clear called (Apple user info preserved)")
            },
            
            loadAppleUserInfo: { appleUserId in
                let defaults = UserDefaults.standard
                guard let data = defaults.data(forKey: appleUsersKey),
                      let dict = try? JSONDecoder().decode([String: AppleUserInfo].self, from: data),
                      let info = dict[appleUserId]
                else {
                    print("[UserStorage] loadAppleUserInfo: not found for \(appleUserId)")
                    return nil
                }
                print("[UserStorage] loadAppleUserInfo: found \(info.name) for \(appleUserId)")
                return (info.name, info.email)
            },
            
            saveAppleUserInfo: { appleUserId, name, email in
                let defaults = UserDefaults.standard
                var dict: [String: AppleUserInfo] = [:]
                
                if let data = defaults.data(forKey: appleUsersKey),
                   let existing = try? JSONDecoder().decode([String: AppleUserInfo].self, from: data) {
                    dict = existing
                }
                
                dict[appleUserId] = AppleUserInfo(name: name, email: email)
                
                if let data = try? JSONEncoder().encode(dict) {
                    defaults.set(data, forKey: appleUsersKey)
                    print("[UserStorage] saveAppleUserInfo: saved \(name) for \(appleUserId)")
                }
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
            },
            loadAppleUserInfo: { _ in nil },
            saveAppleUserInfo: { _, _, _ in }
        )
    }
}

private struct AppleUserInfo: Codable {
    let name: String
    let email: String?
}

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
