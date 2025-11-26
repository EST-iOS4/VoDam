    import Foundation
    import OSLog


    // MARK: Domain Interface
    protocol AlanLLMInterface: Sendable {
        func question(_ question: AlanClient.Question) async throws -> AlanClient.Answer
        func resetState(token: AlanClient.AuthToken) async throws
    }


    // MARK: Domain
    nonisolated
    struct AlanClient: AlanLLMInterface {
        
        static let shared = AlanClient()
        
        // MARK: core
        nonisolated let id = ID(URL(string: "https://kdt-api-function.azurewebsites.net/api/v1")!)
        nonisolated let logger = Logger(subsystem: "AlanClient.AlanLLMFlow", category: "Domain")
        
        
        // MARK: flows
        @concurrent
        func question(_ question: Question) async throws -> Answer {
            // configure url
            let token = AuthToken.current
            
            guard var urlComponents = URLComponents(string: "\(id.value.absoluteString)/question") else {
                logger.error("URL 생성 실패")
                throw AlanClient.Error.invalidURL
            }
            
            urlComponents.queryItems = [
                URLQueryItem(name: "content", value: question.content),
                URLQueryItem(name: "client_id", value: token.value)
            ]
            
            guard let url = urlComponents.url else {
                logger.error("URL Components로부터 URL 생성 실패")
                throw AlanClient.Error.invalidURL
            }
            
            logger.info("API 요청: \(url.absoluteString, privacy: .public)")
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("HTTP 응답 변환 실패")
                    throw AlanClient.Error.invalidResponse
                }
                
                guard httpResponse.statusCode == 200 else {
                    logger.error("HTTP 오류: 상태 코드 \(httpResponse.statusCode) - \(httpResponse) ")
                    if let bodyString = String(data: data, encoding: .utf8) {
                        logger.error("HTTP 오류 응답 바디: \(bodyString, privacy: .public)")
                    } else {
                        logger.error("HTTP 오류 응답 바디 디코딩 실패")
                    }
                    throw AlanClient.Error.httpError(statusCode: httpResponse.statusCode)
                }
                
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(AlanClient.Answer.self, from: data)
                
                logger.info("API 응답 성공: \(apiResponse.content, privacy: .public)")
                return apiResponse
                
            } catch let error as DecodingError {
                logger.error("디코딩 오류: \(error.localizedDescription, privacy: .public)")
                throw AlanClient.Error.decodingError(error)
            } catch let error as AlanClient.Error {
                throw error
            } catch {
                logger.error("네트워크 오류: \(error.localizedDescription, privacy: .public)")
                throw AlanClient.Error.networkError(error)
            }
        }
        
        @concurrent
        func resetState(token: AuthToken = .current) async throws {
            guard let url = URL(string: "\(id.value.absoluteString)/reset-state") else {
                logger.error("URL 생성 실패")
                throw AlanClient.Error.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody = ["client_id": token.value]
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            logger.info("상태 초기화 요청")
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("HTTP 응답 변환 실패")
                    throw AlanClient.Error.invalidResponse
                }
                
                guard httpResponse.statusCode == 200 else {
                    logger.error("HTTP 오류: 상태 코드 \(httpResponse.statusCode)")
                    throw AlanClient.Error.httpError(statusCode: httpResponse.statusCode)
                }
                
                logger.info("상태 초기화 성공")
                
            } catch let error as AlanClient.Error {
                throw error
            } catch {
                logger.error("네트워크 오류: \(error.localizedDescription, privacy: .public)")
                throw AlanClient.Error.networkError(error)
            }
        }
        

        
        // MARK: value
        nonisolated
        enum Error: Swift.Error, LocalizedError {
            case invalidURL
            case invalidResponse
            case networkError(Swift.Error)
            case decodingError(Swift.Error)
            case httpError(statusCode: Int)

            var errorDescription: String? {
                switch self {
                case .invalidURL:
                    return "유효하지 않은 URL입니다."
                case .invalidResponse:
                    return "서버 응답이 유효하지 않습니다."
                case .networkError(let error):
                    return "네트워크 오류: \(error.localizedDescription)"
                case .decodingError(let error):
                    return "데이터 파싱 오류: \(error.localizedDescription)"
                case .httpError(let statusCode):
                    return "HTTP 오류 (상태 코드: \(statusCode))"
                }
            }
        }
        
        nonisolated
        struct Question: Sendable, Hashable, Identifiable {
            // MARK: codr
            let id: ID = ID()
            let content: String
            
            init(_ content: String) {
                self.content = content
            }
            
            
            // MARK: value
            struct ID: Sendable, Hashable {
                let rawValue = UUID()
            }
        }
        
        nonisolated
        struct Answer: Sendable, Codable {
            // MARK: core
            let action: Action
            let content: String
            
            nonisolated
            struct Action: Sendable, Codable {
                let name: String
                let speak: String
            }
        }
        
        nonisolated
        struct AuthToken {
            // MARK: core
            let value: String
            init(_ value: String) {
                self.value = value
            }
            
            static let current: AuthToken = .init(
                {
                    guard let token = Bundle.main.object(forInfoDictionaryKey: "ALAN_API_KEY") as? String,
                          !token.isEmpty else {
                        fatalError("ALAN_API_KEY가 Info.plist에 설정되지 않았습니다. Secrets.xcconfig의 TOKEN 값을 Info.plist에 추가해주세요.")
                    }
                    return token
                }()
            )
        }
        
        nonisolated
        struct ID: Sendable, Hashable {
            // MARK: core
            let value: URL
            fileprivate init(_ value: URL) {
                self.value = value
            }
        }
    }
