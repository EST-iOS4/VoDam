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
        
        var currentUser: User?
        var pendingDeletion: Bool = false
        
        @ObservationStateIgnored var player: AVPlayer?
        var isPlaying = false
        var totalTime: String = "00:00"
        var currentTime: String = "00:00"
        var progress: Double = 0.0
        var playbackRate: Float = 1.0
        var isFavorite: Bool = false
        
        var isPlayerReady = false
        
        var totalSeconds: Double = 0
        
        var isSearching = false
        var searchText = ""
        
        init(project: Project, currentUser: User?, selectedTab: Tab = .script) {
            self.project = project
            self.currentUser = currentUser
            self.selectedTab = selectedTab
            self.isFavorite = project.isFavorite
            
            var transcriptText = project.transcript ?? ""
            
            if transcriptText.isEmpty {
                if project.category == .pdf {
                    transcriptText = "PDF에서 추출한 스크립트가 없습니다."
                } else {
                    transcriptText = "아직 받아온 스크립트가 없습니다."
                }
            }
            
            if project.category == .pdf,
               transcriptText.contains("(전체 텍스트는 Storage에 저장됨)") {
                transcriptText = "전체 스크립트를 불러오는 중..."
            }
            
            self.script = ScriptFeature.State(text: transcriptText)
            
            self.aiSummary = AISummaryFeature.State(
                transcript: transcriptText,
                savedSummary: project.summary,
                projectId: project.id.uuidString,
                ownerId: currentUser?.ownerId
            )
        }
    }
    
    enum Action: BindableAction {
        case script(ScriptFeature.Action)
        case aiSummary(AISummaryFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        case binding(BindingAction<State>)
        case delegate(DelegateAction)
        
        case onAppear
        case playButtonTapped
        case backwardButtonTapped
        case forwardButtonTapped
        case setPlaybackRate(Float)
        
        case favoriteButtonTapped
        case deleteProjectButtonTapped
        
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
        case deleteProjectConfirmed
        case _setupPlayerWithURL(URL)
        case _playerReady(AVPlayer, Double)
        
        case _downloadTranscriptIfNeeded
        case _transcriptDownloaded(String)
        
//        case clearAlert
        
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
                    if let transcript = state.project.transcript,
                       transcript.contains("(전체 텍스트는 Storage에 저장됨)") {
                        return .send(._downloadTranscriptIfNeeded)
                    }
                    return .none
                }
                
                if state.project.category == .pdf {
                    return .none
                }
                
                if state.isPlayerReady {
                    return .none
                }
                
                if let filePath = state.project.filePath,
                   FileManager.default.fileExists(atPath: filePath) {
                    return setupPlayerEffect(fileURL: URL(fileURLWithPath: filePath))
                }
                
                guard let remotePath = state.project.remoteAudioPath,
                      !remotePath.isEmpty else {
                    return .none
                }
                
                guard let ownerId = state.currentUser?.ownerId else {
                    return .none
                }
                
                let projectId = state.project.id.uuidString
                let currentFilePath = state.project.filePath
                
                return .run { send in
                    do {
                        let localPath = try await fileCloudClient.downloadFileIfNeeded(
                            ownerId,
                            projectId,
                            remotePath,
                            currentFilePath
                        )
                        await send(._setupPlayerWithURL(URL(fileURLWithPath: localPath)))
                    } catch {
                        print("[AudioDetail] Firebase 다운로드 실패: \(error)")
                    }
                }
                
            case ._downloadTranscriptIfNeeded:
                guard let ownerId = state.currentUser?.ownerId else {
                    return .none
                }
                
                let projectId = state.project.id.uuidString
                
                return .run { [fileCloudClient] send in
                    do {
                        let transcriptRemotePath = "users/\(ownerId)/files/\(projectId)_transcript.txt"
                        
                        guard let documentsDir = FileManager.default.urls(
                            for: .documentDirectory,
                            in: .userDomainMask
                        ).first else { return }
                        
                        let localTranscriptPath = documentsDir
                            .appendingPathComponent("\(projectId)_transcript.txt")
                            .path
                        
                        if FileManager.default.fileExists(atPath: localTranscriptPath) {
                            let fullText = try String(contentsOfFile: localTranscriptPath, encoding: .utf8)
                            await send(._transcriptDownloaded(fullText))
                            return
                        }
                        
                        let downloadedPath = try await fileCloudClient.downloadFileIfNeeded(
                            ownerId,
                            "\(projectId)_transcript",
                            transcriptRemotePath,
                            localTranscriptPath
                        )
                        
                        let fullText = try String(contentsOfFile: downloadedPath, encoding: .utf8)
                        await send(._transcriptDownloaded(fullText))
                        
                    } catch {
                        print("[AudioDetail] Transcript 다운로드 실패: \(error)")
                    }
                }
                
            case ._transcriptDownloaded(let fullText):
                print("[AudioDetail] Transcript 다운로드 완료: \(fullText.count)자")
                print("[AudioDetail] 현재 script.text 길이: \(state.script.text.count)자")
                
                state.script.text = fullText
                state.aiSummary.transcript = fullText
                state.project.transcript = fullText
                
                let projectId = state.project.id.uuidString
                
                return .run { [projectLocalDataClient] _ in
                    try? await projectLocalDataClient.update(
                        projectId,
                        nil,
                        nil,
                        fullText,
                        nil,
                        nil
                    )
                }
                
            case ._setupPlayerWithURL(let url):
                return setupPlayerEffect(fileURL: url)
                
            case ._playerReady(let player, let totalSeconds):
                state.player = player
                state.isPlayerReady = true
                // FIXED: Store totalSeconds in state for later use
                state.totalSeconds = totalSeconds
                if !totalSeconds.isNaN && !totalSeconds.isInfinite {
                    state.totalTime = formatTime(totalSeconds)
                }
                return startPlayerObservation(player: player, totalSeconds: totalSeconds)
                
            case .playButtonTapped:
                if state.player == nil {
                    state.isPlayerReady = false
                    return .send(.onAppear)
                }
                
                guard let player = state.player else {
                    return .none
                }
                
                state.isPlaying.toggle()
                
                if state.isPlaying {
                    player.play()
                    player.rate = state.playbackRate
                    
                    if player.currentItem != nil {
                        let totalSeconds = state.totalSeconds
                        return startPlayerObservation(player: player, totalSeconds: totalSeconds)
                    }
                } else {
                    player.pause()
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
                let newIsFavorite = state.isFavorite
                state.project.isFavorite = newIsFavorite
                let ownerId = state.currentUser?.ownerId
                let project = state.project
                
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        try await projectLocalDataClient.update(
                            project.id.uuidString,
                            nil,
                            newIsFavorite,
                            nil,
                            nil,
                            nil
                        )
                        
                        if let ownerId {
                            let payload = ProjectPayload(
                                id: project.id.uuidString,
                                name: project.name,
                                creationDate: project.creationDate,
                                category: project.category,
                                isFavorite: newIsFavorite,
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
                
                guard state.player != nil, state.player?.currentItem != nil
                else { return .none }
                let totalSeconds = state.totalSeconds
                let currentTimeSeconds = totalSeconds * progress
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
                guard let player = state.player,
                      player.currentItem != nil else { return .none }
                let clampedProgress = min(max(progress, 0), 1)
                let totalSeconds = state.totalSeconds
                let targetTime = totalSeconds * clampedProgress
                player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 1))
                
                if !targetTime.isNaN && !targetTime.isInfinite {
                    state.currentTime = formatTime(targetTime)
                    state.progress = clampedProgress
                }
                return .none
                
            case .setTotalTime(let timeString):
                state.totalTime = timeString
                return .none
                
            case .chatButtonTapped:
                let project = state.project
                let roomId = project.id.uuidString
                let title = project.name
                
                guard let ownerId = state.currentUser?.ownerId else {
                    state.destination = .alert(
                        AlertState {
                            TextState("로그인이 필요합니다.")
                        } actions: {
                            ButtonState(role: .cancel) {
                                TextState("확인")
                            }
                        } message: {
                            TextState("로그인 후 채팅을 이용할 수 있습니다.")
                        }
                    )
                    return .none
                }
                
                state.destination = .chattingRoom(
                    ChattingRoomFeature.State(ownerId: ownerId, roomId: roomId, title: title)
                )
                return .run { [firebaseClient] _ in
                    try? await firebaseClient.createChatRoom(ownerId, roomId, title)
                }
                
//            case .clearAlert:
//                if case .alert = state.destination {
//                    state.destination = nil
//                }
//                return .none
                
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
                state.selectedTab = .script
                return .none
                
            case .destination(.presented(.alert(.confirmDelete))):
                return .send(.deleteProjectConfirmed)
                
            case .destination(.dismiss):
                state.pendingDeletion = false
                return .none
                
            case .destination(.presented(.editTitle(.delegate(.didFinish(let updatedProject))))):
                state.project = updatedProject
                state.project.isFavorite = state.isFavorite
                state.destination = nil
                return .send(.delegate(.needsRefresh))
                
            case .destination(.presented(.chattingRoom(.delegate(.didDeleteRoom)))):
                state.destination = nil
                return .none
                
            case .script(.delegate(.seekToProgress(let progress))):
                guard state.project.category != .pdf else { return .none }
                let clampedProgress = min(max(progress, 0), 1)
                state.selectedTab = .script
                state.progress = clampedProgress
                
                if !state.isPlaying {
                    return .merge(
                        .send(.seek(clampedProgress)),
                        .send(.playButtonTapped)
                    )
                } else {
                    return .send(.seek(clampedProgress))
                }
                
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
                
            case .deleteProjectButtonTapped:
                state.pendingDeletion = true
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
                guard state.pendingDeletion else {
                    return .none
                }
                state.pendingDeletion = false
                let projectIdString = state.project.id.uuidString
                let ownerId = state.currentUser?.ownerId
                let localFilePath = state.project.filePath
                let remoteAudioPath = state.project.remoteAudioPath
                let isPDF = state.project.category == .pdf
                
                if let player = state.player {
                    player.pause()
                    player.replaceCurrentItem(with: nil)
                }
                state.player = nil
                state.isPlaying = false
                state.isPlayerReady = false
                
                return .merge(
                    .cancel(id: "player_observer"),
                    .run { [projectLocalDataClient, firebaseClient, fileCloudClient] send in
                        do {
                            try await projectLocalDataClient.delete(projectIdString)
                            
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
                            
                            if isPDF {
                                if let documentsDir = FileManager.default.urls(
                                    for: .documentDirectory,
                                    in: .userDomainMask
                                ).first {
                                    let transcriptPath = documentsDir
                                        .appendingPathComponent("\(projectIdString)_transcript.txt")
                                        .path
                                    
                                    if FileManager.default.fileExists(atPath: transcriptPath) {
                                        do {
                                            try FileManager.default.removeItem(atPath: transcriptPath)
                                            print("로컬 transcript 파일 삭제 완료: \(transcriptPath)")
                                        } catch {
                                            print("로컬 transcript 파일 삭제 실패 (계속 진행): \(error)")
                                        }
                                    }
                                }
                            }
                            
                            if let ownerId {
                                do {
                                    try await firebaseClient.deleteProject(
                                        ownerId,
                                        projectIdString
                                    )
                                    if let remoteAudioPath, !remoteAudioPath.isEmpty {
                                        do {
                                            try await fileCloudClient.deleteFile(remoteAudioPath)
                                            print("Storage 파일 삭제 완료: \(remoteAudioPath)")
                                        } catch {
                                            print("Storage 파일 삭제 실패 (계속 진행): \(error)")
                                        }
                                    }
                                    
                                    if isPDF {
                                        let transcriptRemotePath = "users/\(ownerId)/files/\(projectIdString)_transcript.txt"
                                        do {
                                            try await fileCloudClient.deleteFile(transcriptRemotePath)
                                            print("Storage transcript 파일 삭제 완료: \(transcriptRemotePath)")
                                        } catch {
                                            print("Storage transcript 파일 삭제 실패 (계속 진행): \(error)")
                                        }
                                    }
                                    
                                    try await firebaseClient.deleteChatRoom(ownerId, projectIdString)
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
                )
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }
    
    private func setupPlayerEffect(fileURL: URL) -> Effect<Action> {
        .run { send in
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return
            }
            
            do {
                let session = AVAudioSession.sharedInstance()
                let currentCategory = session.category
                
                if currentCategory != .playback {
                    try session.setCategory(.playback, mode: .default, options: [])
                    try session.setActive(true, options: [.notifyOthersOnDeactivation])
                }
            } catch {
                print("[AudioDetail] AVAudioSession 설정 실패: \(error)")
            }
            
            let asset = AVURLAsset(url: fileURL)
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                
                if seconds <= 0.1 || seconds.isNaN || seconds.isInfinite {
                    return
                }
            } catch {
                return
            }
            
            let player = AVPlayer(url: fileURL)
            
            guard player.currentItem != nil else {
                return
            }
            
            let totalSeconds: Double
            do {
                let duration = try await asset.load(.duration)
                totalSeconds = CMTimeGetSeconds(duration)
            } catch {
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
