//
//  AudioDetailFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import AVFoundation
import ComposableArchitecture
import Foundation
import SwiftUI
import SwiftData


private func formatTime(_ seconds: Double) -> String {
    let minutes = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", minutes, secs)
}

@Reducer
struct AudioDetailFeature {
    
    @Dependency(\.fileCloudClient) var fileCloudClient
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    
    @ObservableState
    struct State: Equatable {
        var project: Project
        var selectedTab: Tab
        
        var script: ScriptFeature.State
        var aiSummary: AISummaryFeature.State
        
        @Presents var destination: Destination.State?
        
        // 유저 정보
        var currentUser: User?
        @ObservationStateIgnored var pendingDeletionContext: ModelContext?
        
        @ObservationStateIgnored var player: AVPlayer?
        var isPlaying = false
        var totalTime: String = "00:00"
        var currentTime: String = "00:00"
        var progress: Double = 0.0
        var playbackRate: Float = 1.0
        var isFavorite: Bool = false
        
        // 검색 관련 상태
        var isSearching = false
        var searchText = ""
        
        init(project: Project, currentUser: User?) {
            self.project = project
            self.currentUser = currentUser
            self.selectedTab = .aiSummary
            self.isFavorite = project.isFavorite
            
            var transcriptText = project.transcript ?? "아직 받아온 스크립트가 없습니다."
            
            if project.category == .pdf, transcriptText.isEmpty {
                if let filePath = project.filePath,
                   FileManager.default.fileExists(atPath: filePath) {
                    print("PDF텍스트 추출")
                    
                    let pdfURL = URL(fileURLWithPath: filePath)
                    if let extractedText = PDFTextExtractor.extractText(from: pdfURL) {
                        transcriptText = extractedText
                        print("[AudioDetail] PDF 텍스트 추출 완료: \(extractedText.count)자")
                    } else {
                        transcriptText = "PDF에서 텍스트를 추출할 수 없습니다."
                        print("[AudioDetail] PDF 텍스트 추출 실패")
                    }
                }
            }
            
            if transcriptText.isEmpty {
                transcriptText = "아직 받아온 스크립트가 없습니다."
            }
            
            self.script = ScriptFeature.State(text: transcriptText)
            
            self.aiSummary = AISummaryFeature.State(
                transcript: transcriptText,
                savedSummary: project.summary,
                projectId: project.id.uuidString,
                ownerId: currentUser?.ownerId
            )
            
            if project.summary != nil {
                print("[AudioDetail] 저장된 요약본 사용 - Alan AI 호출 불필요")
            } else {
                print("[AudioDetail] 요약본 없음 - 사용자가 요청하면 Alan AI 호출")
            }
        }
    }
    
    enum Action: BindableAction {
        case script(ScriptFeature.Action)
        case aiSummary(AISummaryFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        case binding(BindingAction<State>)
        case delegate(DelegateAction)
        
        case onAppear
        case onDisappear
        case playButtonTapped
        case backwardButtonTapped
        case forwardButtonTapped
        case setPlaybackRate(Float)
        case favoriteButtonTapped(ModelContext)
        case updateProgress(Double)
        case playerFinishedPlaying
        case seek(Double)
        case setTotalTime(String)
        case searchButtonTapped
        case searchCancelButtonTapped
        case searchTextChanged(String)
        case searchSubmitted
        case chatButtonTapped
        case editTitleButtonTapped
        case deleteProjectButtonTapped(ModelContext)
        case deleteProjectConfirmed
        case _setupPlayerWithURL(URL)
        case _playerReady(AVPlayer, Double)
        
        enum DelegateAction {
            case needsRefresh
            case didDeleteProject
        }
    }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Scope(state: \.script, action: \.script) {
            ScriptFeature()
        }
        
        Scope(state: \.aiSummary, action: \.aiSummary) {
            AISummaryFeature()
        }
        
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
                    return setupPlayerEffect(fileURL: URL(fileURLWithPath: filePath))
                }
                
                // 2. 로컬 파일이 없으면 Firebase에서 다운로드
                print("[AudioDetail] 로컬 파일 없음 - Firebase에서 다운로드 시도")
                
                guard let remotePath = state.project.remoteAudioPath ?? state.project.filePath,
                      !remotePath.isEmpty else {
                    print("[AudioDetail] remotePath 없음 - 재생 불가")
                    return .none
                }
                
                guard let ownerId = state.currentUser?.ownerId else {
                    print("[AudioDetail] ownerId 없음 - 비회원은 원격 파일 다운로드 불가")
                    return .none
                }
                
                let projectId = state.project.id.uuidString
                let currentFilePath = state.project.filePath
                
                return .run { send in
                    do {
                        print("[AudioDetail] Firebase 다운로드 시작: \(remotePath)")
                        
                        @Dependency(\.fileCloudClient) var fileCloudClient
                        
                        let localPath = try await fileCloudClient.downloadFileIfNeeded(
                            ownerId,
                            projectId,
                            remotePath,
                            currentFilePath
                        )
                        
                        print("[AudioDetail] 다운로드 완료: \(localPath)")
                        await send(._setupPlayerWithURL(URL(fileURLWithPath: localPath)))
                        
                    } catch {
                        print("[AudioDetail] Firebase 다운로드 실패: \(error)")
                    }
                }
                
            case ._setupPlayerWithURL(let url):
                return setupPlayerEffect(fileURL: url)
                
            case ._playerReady(let player, let totalSeconds):
                state.player = player
                if !totalSeconds.isNaN && !totalSeconds.isInfinite {
                    state.totalTime = formatTime(totalSeconds)
                }
                return startPlayerObservation(player: player, totalSeconds: totalSeconds)
                
            case .onDisappear:
                print("[AudioDetail] onDisappear - 플레이어 정리")
                
                if let player = state.player {
                    player.pause()
                    player.replaceCurrentItem(with: nil)
                }
                state.player = nil
                state.isPlaying = false
                
                return .cancel(id: "player_observer")
                
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
                
            case .favoriteButtonTapped(let context):
                state.isFavorite.toggle()
                let newIsFavorite = state.isFavorite
                state.project.isFavorite = newIsFavorite
                let ownerId = state.currentUser?.ownerId
                let project = state.project
                
                return .run { send in
                    do {
                        // 1. Local SwiftData 업데이트
                        try await MainActor.run {
                            try projectLocalDataClient.update(
                                context,
                                project.id.uuidString,
                                nil,
                                newIsFavorite,
                                nil,
                                nil,
                                nil
                            )
                        }
                        
                        // 2. Firebase 업데이트 (로그인 상태일 때)
                        if let ownerId {
                            let payload = await ProjectPayload(
                                id: project.id.uuidString,
                                name: project.name,
                                creationDate: project.creationDate,
                                category: project.category,
                                isFavorite: newIsFavorite, // 변경된 값 사용
                                filePath: project.filePath,
                                fileLength: project.fileLength,
                                transcript: project.transcript,
                                ownerId: ownerId,
                                syncStatus: project.syncStatus
                            )
                            try await firebaseClient.updateProject(ownerId, payload)
                        }
                        
                        await send(.delegate(.needsRefresh))
                        
                    } catch {
                        print("즐겨찾기 업데이트 실패: \(error)")
                    }
                }
                
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
            
            case .chatButtonTapped:
                state.destination = .chattingRoom(
                    ChattingRoomFeature.State(projectName: state.project.name)
                )
                return .none
                
            case .searchButtonTapped:
                state.isSearching = true
                return .none
                
            case .searchCancelButtonTapped:
                state.isSearching = false
                state.searchText = ""
                return .send(.script(.clearSearch))
                
            case .searchTextChanged(let text):
                state.searchText = text
                return .send(.script(.search(text)))
                
            case .searchSubmitted:
                print("[AudioDetail] 검색 실행: \(state.searchText)")
                state.selectedTab = .script
                return .none
            case .destination(.presented(.alert(.confirmDelete))):
                return .send(.deleteProjectConfirmed)
              
            case .destination(.dismiss):
                state.pendingDeletionContext = nil
                return .none
              
            case .destination(.presented(.editTitle(.delegate(.didFinish(let updatedProject))))):
                state.project = updatedProject
                state.project.isFavorite = state.isFavorite
                state.destination = nil
                return .send(.delegate(.needsRefresh))
            case .script, .aiSummary, .binding, .destination, .delegate:
                return .none
            case .editTitleButtonTapped:
                var editableProject = state.project
                editableProject.isFavorite = state.isFavorite
                state.destination = .editTitle(
                    ProjectTitleEditFeature.State(
                        project: editableProject,
                        currentUser: state.currentUser
                    )
                )
                return .none
            case .deleteProjectButtonTapped(let context):
                state.pendingDeletionContext = context
                state.destination = .alert(
                    AlertState {
                        TextState("프로젝트 삭제하시겠습니까?")
                    } actions: {
                        ButtonState(
                            role: .destructive,
                            action: .confirmDelete
                        ) {
                            TextState("삭제")
                        }
                        ButtonState(role: .cancel) {
                            TextState("취소")
                        }
                    } message: {
                        TextState("삭제된 프로젝트는 복원할 수 없습니다.")
                    }
                )
                return .none
                
            case .deleteProjectConfirmed:
                guard let context = state.pendingDeletionContext else {
                    return .none
                }
                state.pendingDeletionContext = nil
                let projectIdString = state.project.id.uuidString
                let ownerId = state.currentUser?.ownerId
                let localFilePath = state.project.filePath
                
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        try await MainActor.run {
                            try projectLocalDataClient.delete(
                                context,
                                projectIdString
                            )
                        }
                        
                        if let localFilePath,
                           FileManager.default.fileExists(atPath: localFilePath)
                        {
                            do {
                                try FileManager.default.removeItem(atPath: localFilePath)
                                print("로컬 파일 삭제 완료: \(localFilePath)")
                            } catch {
                                print("로컬 파일 삭제 실패 (계속 진행): \(error)")
                            }
                        }
                        
                        if let ownerId {
                            do {
                                try await firebaseClient.deleteProject(
                                    ownerId,
                                    projectIdString
                                )
                            } catch {
                                print("Firebase 삭제 실패 (계속 진행): \(error)")
                            }
                        }
                        
                        await send(.delegate(.needsRefresh))
                        await send(.delegate(.didDeleteProject))
                    } catch {
                        print("프로젝트 삭제 실패: \(error)")
                    }
                }
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }
    
    private func setupPlayerEffect(fileURL: URL) -> Effect<Action> {
        .run { send in
            print("[AudioDetail] setupPlayer - fileURL: \(fileURL.path)")
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("[AudioDetail] 파일이 존재하지 않음 → \(fileURL.path)")
                return
            }
            
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
                print("[AudioDetail] AVAudioSession playback 세팅 완료")
            } catch {
                print("[AudioDetail] AVAudioSession 설정 실패: \(error)")
            }
            
            let player = AVPlayer(url: fileURL)
            print("[AudioDetail] AVPlayer 생성 완료")
            
            guard let item = player.currentItem else {
                print("[AudioDetail] currentItem이 nil")
                return
            }
            
            let totalSeconds: Double
            do {
                let duration = try await item.asset.load(.duration)
                totalSeconds = CMTimeGetSeconds(duration)
                print("[AudioDetail] 총 재생 시간: \(totalSeconds)초")
            } catch {
                print("[AudioDetail] duration 로드 실패: \(error)")
                return
            }
            
            await send(._playerReady(player, totalSeconds))
        }
    }
    
    private func startPlayerObservation(player: AVPlayer, totalSeconds: Double) -> Effect<Action> {
        .run { send in
            guard let item = player.currentItem else { return }
            
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(
                        named: .AVPlayerItemDidPlayToEndTime,
                        object: item
                    ) {
                        await send(.playerFinishedPlaying, animation: .default)
                    }
                }
                
                group.addTask {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        
                        let current = CMTimeGetSeconds(player.currentTime())
                        if !current.isNaN && !current.isInfinite {
                            let progress = totalSeconds > 0 ? current / totalSeconds : 0
                            await send(.updateProgress(progress))
                        }
                    }
                }
            }
        }
        .cancellable(id: "player_observer", cancelInFlight: true)
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
            case chattingRoom(ChattingRoomFeature.State)
            case editTitle(ProjectTitleEditFeature.State)
        }
        
        enum Action {
            case alert(Alert)
            case chattingRoom(ChattingRoomFeature.Action)
            case editTitle(ProjectTitleEditFeature.Action)
            
            enum Alert {
                case confirmDelete
            }
        }
        
        var body: some Reducer<State, Action> {
            Scope(state: \.chattingRoom, action: \.chattingRoom) {
                ChattingRoomFeature()
            }
            Scope(state: \.editTitle, action: \.editTitle) {
                ProjectTitleEditFeature()
            }
            Reduce { state, action in
                switch action {
                case .alert:
                    return .none
                case .chattingRoom:
                    return .none
                case .editTitle:
                    return .none
                }
            }
        }
    }
}
