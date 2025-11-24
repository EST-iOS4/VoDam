//
//  FileButtonView.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct FileButtonView: View {
    let store: StoreOf<FileButtonFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

                HStack(spacing: 20) {
                    
                    Image(systemName: "folder.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .frame(width: 56, height: 56)
                        .background(RoundedRectangle(cornerRadius: 24).fill(Color.blue))
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)

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
                    send: FileButtonFeature.Action.importerPresented
                ),
                allowedContentTypes: [.mp3, .wav],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewStore.send(.fileImported(.success(url)))
                    } else {
                        viewStore.send(.fileImported(.failure(.failed)))
                    }

                case .failure:
                    viewStore.send(.fileImported(.failure(.failed)))
                }
            }
        }
    }
}
