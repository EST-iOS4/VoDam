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

struct PDFButtonView: View {
    @Bindable var store: StoreOf<PDFButtonFeature>
    let ownerId: String?
    
    init(store: StoreOf<PDFButtonFeature>, ownerId: String? = nil) {
        self.store = store
        self.ownerId = ownerId
    }
    
    var body: some View {
        VStack(spacing: 16) {
            buttonContent
            
            if let error = store.errorMessage {
                Text("에러: \(error)")
                    .foregroundColor(.red)
                    .font(AppFont.pretendardRegular(size: 12))
                    .padding(.horizontal, 20)
            }
        }
        
        .onChange(of: store.selectedPDFURL) { _, newValue in
            guard let url = newValue else { return }
            store.send(.startOCR(url, ownerId))
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
        .alert($store.scope(state: \.alert, action: \.alert))
        .onDisappear {
            store.send(.clearAlert)
        }
    }
    
    private var buttonContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            HStack(spacing: 20) {
                Image(systemName: "doc.richtext.fill")
                    .foregroundColor(.white)
                    .font(AppFont.pretendardRegular(size: 24))
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.red)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.title)
                        .font(AppFont.pretendardSemiBold(size: 17))
                        .foregroundColor(.primary)
                    
                    if store.isProcessing {
                        HStack(spacing: 8) {
                            Text("OCR 변환 중... \(Int(store.progress * 100))%")
                                .font(AppFont.pretendardRegular(size: 12))
                                .foregroundColor(.secondary)
                        }
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
                store.send(.loginRequiredTapped)
            } else {
                store.send(.tapped)
            }
        }
    }
}

