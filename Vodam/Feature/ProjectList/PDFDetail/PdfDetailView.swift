//
//  PdfDetailView.swift
//  Vodam
//
//  Created by 서정원 on 11/19/25.
//

//import ComposableArchitecture
//import SwiftUI
//
//struct PdfDetailView: View {
//    @Bindable var store: StoreOf<PdfDetailFeature>
//    
//    var body: some View {
//        VStack(spacing: 20) {
//                   Spacer()
//                   
//                   Image(systemName: "doc.richtext.fill")
//                       .font(.system(size: 80))
//                       .foregroundColor(.red)
//                   
//                   Text(store.project.name)
//                       .font(.title2)
//                       .fontWeight(.bold)
//                   
//                   Text("PDF 문서")
//                       .font(.headline)
//                       .foregroundColor(.secondary)
//                   
//                   Text(store.project.creationDate, style: .date)
//                       .font(.subheadline)
//                       .foregroundColor(.secondary)
//                   
//                   Button(action: { store.send(.favoriteButtonTapped) }) {
//                       HStack {
//                           Image(systemName: store.isFavorite ? "star.fill" : "star")
//                               .font(.title2)
//                           Text(store.isFavorite ? "즐겨찾기에서 제거" : "즐겨찾기에 추가")
//                       }
//                       .foregroundColor(.blue)
//                       .padding()
//                       .background(Color.blue.opacity(0.1))
//                       .cornerRadius(10)
//                   }
//                   
//                   Spacer()
//               }
//               .padding()
//               .navigationTitle(store.project.name)
//               .navigationBarTitleDisplayMode(.inline)
//               .toolbar {
//                   ToolbarItem(placement: .navigationBarTrailing) {
//                       Menu {
//                           Button(action: { store.send(.editTitleButtonTapped) }) {
//                               Label("제목 수정", systemImage: "pencil")
//                           }
//                           
//                           Button(role: .destructive) {
//                               store.send(.deleteProjectButtonTapped)
//                           } label: {
//                               Label("삭제", systemImage: "trash")
//                           }
//                       } label: {
//                           Image(systemName: "ellipsis.circle")
//                       }
//                   }
//               }
//    }
//}
