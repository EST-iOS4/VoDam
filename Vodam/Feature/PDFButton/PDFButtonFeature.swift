//
//  PDFButtonFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct PDFButtonFeature {

    @ObservableState
    struct State: Equatable {
        var title: String = "PDF 가져오기"
        var selectedPDFURL: URL? = nil //선택한 PDF파일의 주소를 가짐
        var isImporterPresented: Bool = false //파일 선택하는 창(UI)를 불러오는 Bo
        var isProcessing: Bool = false
    }

    // PDF 선택 에러
    enum PDFImportError: Error, Equatable {
        case failed
    }

    enum Action: Equatable {
        case tapped
        case importerPresented(Bool)
        case pdfImported(Result<URL, PDFImportError>)
        case processingStarted
        case processingFinished
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

            case .processingStarted:
                state.isProcessing = true
                return .none

            case .processingFinished:
                state.isProcessing = false
                state.selectedPDFURL = nil
                return .none
                
            case let .pdfImported(result):
                switch result {
                case .success(let url):
                    print("📄 선택된 PDF 파일:", url)
                    state.selectedPDFURL = url
                case .failure:
                    print("❌ PDF 파일 가져오기 실패")
                }
                return .none
            }
        }
    }
}
