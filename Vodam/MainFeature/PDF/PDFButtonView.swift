//
//  PDFButtonView.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct PDFButtonView: View {
    let store: StoreOf<PDFButtonFeature>

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
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)

                    // 텍스트
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewStore.title)
                            .font(.headline)
                            .foregroundColor(.black)
                    }

                    Spacer()
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
        }
    }
}
