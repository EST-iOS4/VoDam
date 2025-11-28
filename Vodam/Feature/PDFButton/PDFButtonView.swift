//
//  PDFButtonView.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import SwiftData

struct PDFButtonView: View {
    let store: StoreOf<PDFButtonFeature>

    @Environment(\.modelContext) var context
    let ownerId: String?

    init(store: StoreOf<PDFButtonFeature>, ownerId: String? = nil) {
        self.store = store
        self.ownerId = ownerId
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                // 카드 배경
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

                // 내부 UI
                HStack(spacing: 20) {

                    // 아이콘 (FileButtonView와 동일한 구조로 수정)
                    Image(systemName: "doc.richtext.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.red)
                        )
                        .shadow(
                            color: .black.opacity(0.15),
                            radius: 3,
                            x: 0,
                            y: 2
                        )

                    // 텍스트
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewStore.title)
                            .font(.headline)

                        if viewStore.isProcessing {
                            Text("텍스트 추출 중...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                    }

                    Spacer()

                    if viewStore.isProcessing {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 80)
            .padding(.horizontal, 20)
            .onTapGesture {
                viewStore.send(.tapped)
            }
            .fileImporter(
                isPresented: viewStore.binding(
                    get: \.isImporterPresented,
                    send: PDFButtonFeature.Action.importerPresented
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewStore.send(.pdfImported(.success(url)))
                    } else {
                        viewStore.send(.pdfImported(.failure(.failed)))
                    }

                case .failure:
                    viewStore.send(.pdfImported(.failure(.failed)))
                }
            }
            .onChange(of: viewStore.selectedPDFURL) { _, newValue in
                guard let url = newValue else { return }
                // Feature의 savePDF 액션 호출
                viewStore.send(.savePDF(url, context, ownerId))
            }
        }
    }
}
