//
//  FileButtonView.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct FileButtonView: View {
    @Bindable var store: StoreOf<FileButtonFeature>
    let ownerId: String?
    
    init(store: StoreOf<FileButtonFeature>, ownerId: String? = nil) {
        self.store = store
        self.ownerId = ownerId
    }
    
    var body: some View {
        VStack(spacing: 16) {
            buttonContent
            
            if let error = store.errorMessage {
                Text("에러: \(error)")
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
            }
        }
        .onChange(of: store.isTranscribing) { wasTranscribing, isTranscribing in
            if !isTranscribing,
               wasTranscribing,
               let url = store.selectedFileURL,
               store.errorMessage == nil {
                
                let transcript = store.transcript.isEmpty ? nil : store.transcript
                store.send(.saveFile(url, transcript, ownerId))
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .onDisappear {
            store.send(.clearAlert)
        }
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            HStack(spacing: 20) {
                iconView
                
                textContent
                
                Spacer()
                
                if store.isTranscribing {
                    ProgressView()
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
        .onTapGesture {
            if ownerId == nil {
                store.send(.loginRequiredTapped)
            } else {
                store.send(.tapped)
            }
        }
        .fileImporter(
            isPresented: $store.isImporterPresented.sending(\.importerPresented),
            allowedContentTypes: [.wav, .mp3, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.send(.fileImported(.success(url)))
                } else {
                    store.send(.fileImported(.failure(.failed)))
                }
            case .failure:
                store.send(.fileImported(.failure(.failed)))
            }
        }
    }
    
    private var iconView: some View {
        Image(systemName: "folder.fill")
            .foregroundColor(.white)
            .font(AppFont.pretendardRegular(size: 24))
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 24).fill(Color.blue)
            )
            .shadow(
                color: Color.primary.opacity(0.15),
                radius: 3,
                x: 0,
                y: 2
            )
    }
    
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.title)
                .font(AppFont.pretendardSemiBold(size: 17))
                .foregroundColor(.primary)
            
            if store.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView(value: store.progress)
                        .frame(width: 100)
                    
                    Text("\(Int(store.progress * 100))%")
                        .font(AppFont.pretendardRegular(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
