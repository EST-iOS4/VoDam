//
//  FileButtonView.swift
//  VoDam
//

import ComposableArchitecture
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct FileButtonView: View {
    @Environment(\.modelContext) var context
    let store: StoreOf<FileButtonFeature>
    let ownerId: String?
    
    init(store: StoreOf<FileButtonFeature>, ownerId: String? = nil) {
        self.store = store
        self.ownerId = ownerId
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 16) {
                buttonContent(viewStore)
                
                if let error = viewStore.errorMessage {
                    Text("에러: \(error)")
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
            }
            // STT 완료 후 저장 처리
            .onChange(of: viewStore.isTranscribing) { wasTranscribing, isTranscribing in
                // STT가 완료되었고 (false), 선택된 파일이 있고, 에러가 없을 때
                if !isTranscribing && wasTranscribing,
                   let url = viewStore.selectedFileURL,
                   viewStore.errorMessage == nil {
                    let transcript = viewStore.transcript.isEmpty ? nil : viewStore.transcript
                    // Feature의 saveFile 액션 호출
                    viewStore.send(.saveFile(url, transcript, context, ownerId))
                }
            }
        }
    }
    
    // MARK: - Button Content
    @ViewBuilder
    private func buttonContent(_ viewStore: ViewStoreOf<FileButtonFeature>) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 6,
                    x: 0,
                    y: 4
                )

            HStack(spacing: 20) {
                iconView
                
                textContent(viewStore)
                
                Spacer()
                
                if viewStore.isTranscribing {
                    ProgressView()
                        .padding(.trailing, 8)
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
                send: FileButtonFeature.Action.importerPresented
            ),
            allowedContentTypes: [.wav, .mp3, .mpeg4Audio],
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
    
    @ViewBuilder
    private var iconView: some View {
        Image(systemName: "folder.fill")
            .foregroundColor(.white)
            .font(.system(size: 24))
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 24).fill(Color.blue)
            )
            .shadow(
                color: .black.opacity(0.15),
                radius: 3,
                x: 0,
                y: 2
            )
    }
    
    @ViewBuilder
    private func textContent(_ viewStore: ViewStoreOf<FileButtonFeature>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewStore.title)
                .font(.headline)
                .foregroundColor(.black)
            
            if viewStore.isTranscribing {
                Text("변환 중...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}
