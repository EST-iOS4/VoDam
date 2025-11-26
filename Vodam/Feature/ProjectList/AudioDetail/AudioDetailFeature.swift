//
//  AudioDetailFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import AVFoundation
import ComposableArchitecture


@Reducer
struct AudioDetailFeature {
    @ObservableState
    struct State: Equatable {
        let project: Project
        var selectedTab: Tab
        
        var script: ScriptFeature.State
        var aiSummary: AISummaryFeature.State
        
        @Presents var destination: Destination.State?

        @ObservationStateIgnored var player: AVPlayer?
        var isPlaying = false
        var totalTime: String = "00:00"
        var currentTime: String = "00:00"
        var progress: Double = 0.0
        var playbackRate: Float = 1.0
        var isFavorite: Bool = false
        
        init(project: Project) {
            self.project = project
            self.selectedTab = .aiSummary
            self.script = ScriptFeature.State()
            self.aiSummary = AISummaryFeature.State()
            self.isFavorite = project.isFavorite
        }
    }
    
    enum Action: BindableAction {
        case script(ScriptFeature.Action)
        case aiSummary(AISummaryFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        case binding(BindingAction<State>)
        
        case onAppear
        case playButtonTapped
        case backwardButtonTapped
        case forwardButtonTapped
        case setPlaybackRate(Float)
        case favoriteButtonTapped
        case updateProgress(Double)
        case playerFinishedPlaying
        case seek(Double)
        case setTotalTime(String)
        case searchButtonTapped
        case chatButtonTapped
        case editTitleButtonTapped
        case deleteProjectButtonTapped
    }
    
    nonisolated private enum CancelID { case playerObserver }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let url = Bundle.main.url(
                    forResource: "sample", withExtension: "mp4"
                ) else {
                    return .none
                }
                state.player = AVPlayer(url: url)

                return .run { [player = state.player] send in
                    guard let player = player,
                            let item = player.currentItem else { return }
                    let totalSeconds: Double
                    do {
                        let duration = try await item.asset.load(.duration)
                        totalSeconds = CMTimeGetSeconds(duration)
                        if !totalSeconds.isNaN && !totalSeconds.isInfinite {
                            await send(.setTotalTime(formatTime(totalSeconds)))
                        }
                    } catch {
                        //TODO: 오디오 재생 시간을 불러오지 못했다. 라는 에러처리를 해줘야 한다.
                        return
                    }

                    await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            let stream = AsyncStream<Double> { continuation in
                                let timeScale = CMTimeScale(NSEC_PER_SEC)
                                let observer = player.addPeriodicTimeObserver(
                                    forInterval: CMTime(
                                        seconds: 0.5, preferredTimescale: timeScale
                                    ),
                                    queue: .main
                                ) { time in
                                    let progress = totalSeconds > 0 ?
                                    CMTimeGetSeconds(time) / totalSeconds : 0
                                    continuation.yield(progress)
                                }
                                continuation.onTermination = { @Sendable _ in
                                    player.removeTimeObserver(observer)
                                }
                            }
                            for await progress in stream {
                                Task { @MainActor in
                                    send(.updateProgress(progress))
                                }
                            }
                        }

                        group.addTask {
                            for await _ in NotificationCenter.default.notifications(
                                named: .AVPlayerItemDidPlayToEndTime,
                                object: item
                            ) {
                                await send(.playerFinishedPlaying)
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.playerObserver, cancelInFlight: true)
                
            case .playButtonTapped:
                guard let player = state.player else { return .none }
                state.isPlaying.toggle()
                if state.isPlaying {
                    player.play()
                    player.rate = state.playbackRate
                } else {
                    player.pause()
                }
                return .none
                
            case .backwardButtonTapped:
                guard let player = state.player else { return .none }
                let currentTime = player.currentTime()
                let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: currentTime.timescale))
                player.seek(to: newTime)
                return .none
                
            case .forwardButtonTapped:
                guard let player = state.player else { return .none }
                let currentTime = player.currentTime()
                let newTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: currentTime.timescale))
                player.seek(to: newTime)
                return .none
                
            case let .setPlaybackRate(rate):
                state.playbackRate = rate
                if state.isPlaying {
                    state.player?.rate = rate
                }
                return .none
                
            case .favoriteButtonTapped:
                state.isFavorite.toggle()
                // TODO: 즐겨찾기 상태를 저장하는 API 호출 또는 로컬 DB 업데이트 로직 추가
                return .none
                
            case let .updateProgress(progress):
                state.progress = progress
                
                guard let player = state.player, let item = player.currentItem else { return .none }
                let duration = item.asset.duration
                let currentTimeSeconds = CMTimeGetSeconds(duration) * progress
                if !currentTimeSeconds.isNaN && !currentTimeSeconds.isInfinite {
                    state.currentTime = formatTime(currentTimeSeconds)
                }
                
                return .none
                
            case .playerFinishedPlaying:
                state.isPlaying = false
                state.progress = 0.0
                state.player?.seek(to: .zero)
                return .none
            
            case let .seek(progress):
                guard let player = state.player, let item = player.currentItem else { return .none }
                let duration = item.asset.duration
                let targetTime = CMTimeGetSeconds(duration) * progress
                player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 1))
                return .none
                
            case let .setTotalTime(timeString):
                state.totalTime = timeString
                return .none
                
            case .script, .aiSummary, .binding, .destination:
                return .none
            case .searchButtonTapped:
                return .none
            case .chatButtonTapped:
                return .none
            case .editTitleButtonTapped:
                return .none
            case .deleteProjectButtonTapped:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
        
        Scope(state: \.script, action: \.script) {
            ScriptFeature()
        }
        
        Scope(state: \.aiSummary, action: \.aiSummary) {
            AISummaryFeature()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension AudioDetailFeature {
    @Reducer
    struct Destination {
        @ObservableState
        enum State: Equatable {
            
        }
        enum Action {
            
        }
        var body: some Reducer<State, Action> {
            Reduce { state, action in
                switch action {
                    
                }
            }
        }
    }
}
