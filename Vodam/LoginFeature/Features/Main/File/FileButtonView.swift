//
//  FileButtonView.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import SwiftUI
import ComposableArchitecture

struct FileButtonView: View {
    let store: StoreOf<FileButtonFeature>

    var body: some View {
        WithViewStore(store, observe: \.title) { viewStore in
            Button {
                viewStore.send(.tapped)
            } label: {
                HStack(spacing: 16) {

                    Image(systemName: "folder.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.15))
                        )

                    Text(viewStore.state)
                        .foregroundColor(.black)
                        .font(.headline)

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
