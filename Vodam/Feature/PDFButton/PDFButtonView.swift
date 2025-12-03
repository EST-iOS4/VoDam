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
    @Environment(\.modelContext) private var context
    @Bindable var store: StoreOf<PDFButtonFeature>
    let ownerId: String?
    
    init(store: StoreOf<PDFButtonFeature>, ownerId: String? = nil) {
        self.store = store
        self.ownerId = ownerId
    }
    
    var body: some View {
        ZStack {
            // 카드 배경
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
            
            // 내부 UI
            HStack(spacing: 20) {
                
                // 아이콘
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
                    Text(store.title)
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    if store.isProcessing {
                        Text("텍스트 추출 중...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if store.isProcessing {
                    ProgressView()
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
                store.send(.tapped)
            }
        }
        .fileImporter(
            isPresented: $store.isImporterPresented.sending(\.importerPresented),
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.send(.pdfImported(.success(url)))
                } else {
                    store.send(.pdfImported(.failure(.failed)))
                }
                
            case .failure:
                store.send(.pdfImported(.failure(.failed)))
            }
        }
        .onChange(of: store.selectedPDFURL) { _, newValue in
            guard let url = newValue else { return }
            store.send(.savePDF(url, context, ownerId))
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .onDisappear {
            store.send(.clearAlert)
        }
    }
}
