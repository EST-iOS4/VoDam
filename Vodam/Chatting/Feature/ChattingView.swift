//
//  ChattingView.swift
//  Vodam
//
//  Created by 이건준 on 11/19/25.
//

import SwiftUI

struct ChattingInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let content: String
    let recentEditedDate: Date
}

struct ChattingView: View {
    let chattingInfo: ChattingInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(chattingInfo.title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(chattingInfo.recentEditedDate.formatted())
                    .font(.system(size: 12, weight: .medium))
            }
            Text(chattingInfo.content)
                .font(.system(size: 12, weight: .medium))
            Spacer()
        }
        .frame(height: 77)
        .padding(.init(top: 8, leading: 9, bottom: 8, trailing: 9))
    }
}
