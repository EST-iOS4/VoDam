import ComposableArchitecture

extension SpeechService: DependencyKey {
    static let liveValue = SpeechService()
}

extension DependencyValues {
    var speechService: SpeechService {
        get { self[SpeechService.self] }
        set { self[SpeechService.self] = newValue }
    }
}
