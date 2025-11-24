//
//  FileButtonFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct FileButtonFeature {

    @ObservableState
    struct State: Equatable {
        var title: String = "파일 가져오기"
        var selectedFileURL: URL? = nil
        var isImporterPresented: Bool = false
    }

    enum Action: Equatable {
        case tapped
        case importerPresented(Bool)
        case fileImported(Result<URL, FileImportError>)
    }

    // 파일 불러오기 실패 에러
    enum FileImportError: Error, Equatable {
        case failed
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .tapped:
                state.isImporterPresented = true
                return .none

            case let .importerPresented(isPresented):
                state.isImporterPresented = isPresented
                return .none

            case let .fileImported(result):
                switch result {
                case .success(let url):
                    print("📁 선택된 파일 URL:", url)
                    state.selectedFileURL = url
                case .failure:
                    print("❌ 파일 선택 실패")
                }
                return .none
            }
        }
    }
}
