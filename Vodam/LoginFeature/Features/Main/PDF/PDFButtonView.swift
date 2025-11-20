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
            Button {
                viewStore.send(.tapped)
            } label: {
                HStack(spacing: 16) {

                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.15))
                        )

                    Text(viewStore.title)
                        .foregroundColor(.black)
                        .font(.headline)

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(
                            color: Color.black.opacity(0.08),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                )
            }
            .buttonStyle(.plain)
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
