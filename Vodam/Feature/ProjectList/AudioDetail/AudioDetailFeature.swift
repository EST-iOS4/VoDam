//
//  AudioDetailFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import AVFoundation
import ComposableArchitecture
import SwiftUI

@Reducer
struct AudioDetailFeature {
    @ObservableState
    struct State: Equatable {
        let project: Project
        let currentUser: User?  // User 정보 추가
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
        
        init(project: Project, currentUser: User?) {
            self.project = project
            self.currentUser = currentUser
            self.selectedTab = .aiSummary
            let transcriptText = project.transcript ?? "아직 받아온 스크립트가 없습니다."
            self.script = ScriptFeature.State(text: transcriptText)
            self.aiSummary = AISummaryFeature.State(transcript: transcriptText)
            self.isFavorite = project.isFavorite
            
            if let savedSummary = project.summary {
                self.aiSummary = AISummaryFeature.State(
                    transcript: transcriptText,
                    savedSummary: savedSummary
                )
            } else {
                self.aiSummary = AISummaryFeature.State(transcript: transcriptText)
            }
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
        
        case _setupPlayerWithURL(URL)
    }
    
    @Dependency(\.fileCloudClient) var fileCloudClient
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    
    nonisolated private enum CancelID { case playerObserver }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                print("[AudioDetail] onAppear 진입 - project: \(state.project.name)")
                
                if state.project.category == .pdf {
                    print("[AudioDetail] PDF 문서 - 오디오 플레이어 초기화 생략")
                    return .none
                }
                
                // 1. 로컬 파일이 있는지 확인
                if let filePath = state.project.filePath,
                   FileManager.default.fileExists(atPath: filePath) {
                    print("[AudioDetail] 로컬 파일 존재 - 바로 재생: \(filePath)")
                    return setupPlayer(state: &state, fileURL: URL(fileURLWithPath: filePath))
                }
                
                // 2. 로컬 파일이 없으면 Firebase에서 다운로드
                print("[AudioDetail] 로컬 파일 없음 - Firebase에서 다운로드 시도")
                
                // remoteAudioPath 우선 사용 (수정됨)
                guard let remotePath = state.project.remoteAudioPath ?? state.project.filePath,
                      !remotePath.isEmpty else {
                    print("[AudioDetail] remotePath 없음 - 재생 불가")
                    return .none
                }
                
                // ownerId 가져오기
                guard let ownerId = state.currentUser?.ownerId else {
                    print("[AudioDetail] ownerId 없음 - 비회원은 원격 파일 다운로드 불가")
                    return .none
                }
                
                return .run { [project = state.project] send in
                    do {
                        // Firebase Storage에서 다운로드
                        print("[AudioDetail] Firebase 다운로드 시작: \(remotePath)")
                        
                        // downloadFileIfNeeded 사용 - 올바른 파라미터 전달
                        let localPath = try await fileCloudClient.downloadFileIfNeeded(
                            ownerId,                    // ownerId (수정됨)
                            project.id.uuidString,      // projectId
                            remotePath,                 // remotePath
                            project.filePath            // currentLocalPath
                        )
                        
                        print("[AudioDetail] 다운로드 완료: \(localPath)")
                        
                        // 플레이어 설정
                        await send(._setupPlayerWithURL(URL(fileURLWithPath: localPath)))
                        
                    } catch {
                        print("[AudioDetail] Firebase 다운로드 실패: \(error)")
                    }
                }
                
            case ._setupPlayerWithURL(let url):
                return setupPlayer(state: &state, fileURL: url)
                
            case .playButtonTapped:
                guard let player = state.player else {
                    print("[AudioDetail] playButtonTapped 호출됐는데 player 가 nil")
                    return .none
                }
                
                state.isPlaying.toggle()
                print("[AudioDetail] playButtonTapped - isPlaying = \(state.isPlaying)")
                
                if state.isPlaying {
                    player.play()
                    player.rate = state.playbackRate
                    print("[AudioDetail] player.play() 호출, rate = \(state.playbackRate)")
                } else {
                    player.pause()
                    print("[AudioDetail] player.pause() 호출")
                }
                return .none
                
            case .backwardButtonTapped:
                guard let player = state.player else { return .none }
                let currentTime = player.currentTime()
                let newTime = CMTimeSubtract(
                    currentTime,
                    CMTime(seconds: 10, preferredTimescale: currentTime.timescale)
                )
                player.seek(to: newTime)
                return .none
                
            case .forwardButtonTapped:
                guard let player = state.player else { return .none }
                let currentTime = player.currentTime()
                let newTime = CMTimeAdd(
                    currentTime,
                    CMTime(seconds: 10, preferredTimescale: currentTime.timescale)
                )
                player.seek(to: newTime)
                return .none
                
            case .setPlaybackRate(let rate):
                state.playbackRate = rate
                if state.isPlaying {
                    state.player?.rate = rate
                }
                return .none
                
            case .favoriteButtonTapped:
                state.isFavorite.toggle()
                // TODO: 즐겨찾기 상태를 저장하는 API 호출 또는 로컬 DB 업데이트 로직 추가
                return .none
                
            case .updateProgress(let progress):
                state.progress = progress
                
                guard let player = state.player, let item = player.currentItem
                else { return .none }
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
                
            case .seek(let progress):
                guard let player = state.player, let item = player.currentItem
                else { return .none }
                let duration = item.asset.duration
                let targetTime = CMTimeGetSeconds(duration) * progress
                player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 1))
                return .none
                
            case .setTotalTime(let timeString):
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
    enum Tab: String, CaseIterable, Equatable {
        case aiSummary = "AI 요약"
        case script = "스크립트"
    }
}

extension AudioDetailFeature {
    @Reducer
    struct Destination {
        @ObservableState
        enum State: Equatable {
            case alert(AlertState<Action.Alert>)
        }
        
        enum Action {
            case alert(Alert)
            
            enum Alert {
                case confirmDelete
            }
        }
        
        var body: some Reducer<State, Action> {
            Reduce { state, action in
                switch action {
                case .alert:
                    return .none
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupPlayer(state: inout State, fileURL: URL) -> Effect<Action> {
        print("[AudioDetail] setupPlayer - fileURL: \(fileURL.path)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[AudioDetail] 파일이 존재하지 않음 → \(fileURL.path)")
            return .none
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("[AudioDetail] AVAudioSession playback 세팅 완료")
        } catch {
            print("[AudioDetail] AVAudioSession 설정 실패: \(error)")
        }
        
        state.player = AVPlayer(url: fileURL)
        print("[AudioDetail] AVPlayer 생성 완료")
        
        return .run { [player = state.player] send in
            guard let player = player, let item = player.currentItem
            else {
                print("[AudioDetail] player 또는 currentItem 이 nil")
                return
            }
            
            let totalSeconds: Double
            do {
                let duration = try await item.asset.load(.duration)
                totalSeconds = CMTimeGetSeconds(duration)
                if !totalSeconds.isNaN && !totalSeconds.isInfinite {
                    await send(.setTotalTime(formatTime(totalSeconds)))
                }
                print("[AudioDetail] 총 재생 시간: \(totalSeconds)초")
            } catch {
                print("[AudioDetail] duration 로드 실패: \(error)")
                return
            }
            
            await withThrowingTaskGroup(of: Void.self) { group in
                // 재생 완료 감지
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(
                        named: .AVPlayerItemDidPlayToEndTime,
                        object: item
                    ) {
                        await send(.playerFinishedPlaying, animation: .default)
                    }
                }
                
                // 재생 진행률 업데이트
                group.addTask {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
                        
                        let current = CMTimeGetSeconds(player.currentTime())
                        if !current.isNaN && !current.isInfinite {
                            let progress = totalSeconds > 0 ? current / totalSeconds : 0
                            await send(.updateProgress(progress))
                        }
                    }
                }
            }
        }
        .cancellable(id: CancelID.playerObserver, cancelInFlight: true)
    }
}
