//
//  FileButtonFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI
import Speech

@Reducer
struct FileButtonFeature {
    
    @Dependency(\.audioFileSTTClient) var sttClient

    @ObservableState
    struct State: Equatable {
        var title: String = "파일 가져오기"
        var selectedFileURL: URL?
        var isImporterPresented: Bool = false
        
        // STT 상태
        var isTranscribing: Bool = false
        var transcript: String = ""
        var errorMessage: String?
    }

    enum Action: Equatable {
        case tapped
        case importerPresented(Bool)
        case fileImported(Result<URL, FileImportError>)
        
        // STT
        case startSTT(URL)
        case sttResponse(Result<String, STTError>)
    }

    enum FileImportError: Error, Equatable {
        case failed
    }

    enum STTError: Error, Equatable {
        case failed(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            // 파일 선택 클릭
            case .tapped:
                state.isImporterPresented = true
                return .none

            case let .importerPresented(isPresented):
                state.isImporterPresented = isPresented
                return .none

            // 파일 선택 후
            case let .fileImported(result):
                switch result {
                case .success(let url):
                    print("📁 선택된 파일:", url)
                    state.selectedFileURL = url
                    // 선택됨 → STT 실행
                    return .send(.startSTT(url))

                case .failure:
                    state.errorMessage = "파일 선택 실패"
                    return .none
                }

            // STT 시작
            case let .startSTT(url):
                state.isTranscribing = true
                print("🎤 STT 시작: \(url.lastPathComponent)")
                return .run { [url, sttClient] send in
                    let result = await sttClient.transcribe(url)
                    await send(.sttResponse(result))
                }

            // STT 결과 전달
            case let .sttResponse(result):
                state.isTranscribing = false
                print("🎤 STT 종료")

                switch result {
                case .success(let text):
                    print("📄 STT 결과:")
                    print(text)   // ← 결과 콘솔 출력
                    state.transcript = text

                case .failure(let error):
                    print("❌ STT 실패:", error)
                    state.errorMessage = "STT 실패: \(error)"
                }
                return .none
            }
        }
    }
}
