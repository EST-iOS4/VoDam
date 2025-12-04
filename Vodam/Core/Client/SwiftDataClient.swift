//
//  SwiftDataClient.swift
//  Vodam
//
//  Created by 송영민 on 12/4/25.
//

import Dependencies
import Foundation
import SwiftData

final class SwiftDataClientImpl: @unchecked Sendable {
    private let container: ModelContainer?
    
    init(container: ModelContainer?) {
        self.container = container
    }
    
    @MainActor
    func withContext<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        guard let container = container else {
            fatalError("SwiftDataClient not configured with ModelContainer")
        }
        return try operation(container.mainContext)
    }
}

struct SwiftDataClient: Sendable {
    private let impl: SwiftDataClientImpl
    
    private static var sharedInstance: SwiftDataClient?
    
    init(container: ModelContainer?) {
        self.impl = SwiftDataClientImpl(container: container)
    }
    
    func withContext(_ operation: @escaping @MainActor (ModelContext) throws -> Void) async throws {
        try await MainActor.run {
            try impl.withContext(operation)
        }
    }
    
    func withContextReturning<T: Sendable>(_ operation: @escaping @MainActor (ModelContext) throws -> T) async throws -> T {
        try await MainActor.run {
            try impl.withContext(operation)
        }
    }
    
    func perform(_ operation: @MainActor (ModelContext) throws -> Void) async throws {
        try await MainActor.run {
            try impl.withContext(operation)
        }
    }
    
    func perform<T: Sendable>(_ operation: @MainActor (ModelContext) throws -> T) async throws -> T {
        try await MainActor.run {
            try impl.withContext(operation)
        }
    }
}

extension SwiftDataClient: DependencyKey {
    
    static var liveValue: SwiftDataClient {
        guard let instance = sharedInstance else {
            fatalError("SwiftDataClient.configure(container:) must be called before use")
        }
        return instance
    }
    
    static let testValue = SwiftDataClient(container: nil)
    
    static func configure(container: ModelContainer) {
        sharedInstance = SwiftDataClient(container: container)
    }
    
    static func live(container: ModelContainer) -> SwiftDataClient {
        SwiftDataClient(container: container)
    }
}

extension DependencyValues {
    var swiftDataClient: SwiftDataClient {
        get { self[SwiftDataClient.self] }
        set { self[SwiftDataClient.self] = newValue }
    }
}
