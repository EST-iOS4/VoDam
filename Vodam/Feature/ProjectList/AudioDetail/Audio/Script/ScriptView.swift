//
//  ScriptView.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

struct ScriptView: View {
    let store: StoreOf<ScriptFeature>
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
            
                Text(store.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)  
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(Color(.systemBackground))
    }
}
