//
//  FileButtonView.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct FileButtonView: View {
    @Environment(\.modelContext) private var context
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
        // STT 완료 후 저장 처리
        .onChange(of: store.isTranscribing) { wasTranscribing, isTranscribing in
            // STT가 완료되었고 (false), 선택된 파일이 있고, 에러가 없을 때
            if !isTranscribing,
               wasTranscribing,
               let url = store.selectedFileURL,
               store.errorMessage == nil {
                
                let transcript = store.transcript.isEmpty ? nil : store.transcript
                store.send(.saveFile(url, transcript, context, ownerId))
            }
        }
        // Feature 쪽 AlertState 사용
        .alert($store.scope(state: \.alert, action: \.alert))
    }
    
    // MARK: - Button Content
    private var buttonContent: some View {
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
                store.send(.loginRequiredTapped)   // ✅ 비로그인 → Alert
            } else {
                store.send(.tapped)                // ✅ 로그인 → 기존 동작
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
    
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.title)
                .font(.headline)
                .foregroundColor(.black)
            
            if store.isTranscribing {
                Text("변환 중...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}
