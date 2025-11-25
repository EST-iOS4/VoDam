//
//  AlanClient.swift
//  Vodam
//
//  Created by EunYoung Wang on 11/25/25.
//

import Foundation

import Foundation

// MARK: - Response Model
struct AlanQuestionResponse: Decodable {
    struct Action: Decodable {
        let name: String
        let speak: String
    }
    let action: Action?
    let content: String
}

// MARK: - API Client
struct AlanClient {
    static let shared = AlanClient()
    
    private var apiKey: String {
        ProcessInfo.processInfo.environment["ALAN_API_KEY"] ?? ""
    }
    
    private let baseURL = "https://kdt-api-function.azurewebsites.net/api/v1"
    
    func sendQuestion(content: String, clientID: String) async throws -> String {
        var components = URLComponents(string: baseURL)!
        components.path = "/api/v1/question"
        components.queryItems = [
            .init(name: "content", value: content),
            .init(name: "client_id", value: clientID)
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        //request 생성
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        //통신
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let response = try JSONDecoder().decode(AlanQuestionResponse.self, from: data)
        return response.content
    }
}

