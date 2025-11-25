//
//  UserStorageClient.swift
//  Vodam
//
//  Created by 송영민 on 11/25/25.
//

import Dependencies
import Foundation

struct UserStorageClient {
    var load: @Sendable () -> User?
    var save: @Sendable (User?) -> Void
    var clear: @Sendable () -> Void
}

extension UserStorageClient: DependencyKey {
    static var liveValue: UserStorageClient {
        let key = "currentUser"

        return .init(
            load: {
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
            },
            save: { user in
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
            },
            clear: {
                UserDefaults.standard.removeObject(forKey: key)
            }
        )
    }
    
    static var testValue: UserStorageClient {
        var storedUser: User?
        
        return .init(
            load: {
                storedUser
            },
            save: { user in
                storedUser = user
            },
            clear: {
                storedUser = nil
            }
        )
    }
}

extension DependencyValues {
    var userStorageClient: UserStorageClient {
        get { self[UserStorageClient.self] }
        set { self[UserStorageClient.self] = newValue }
    }
}
