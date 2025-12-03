//
//  ChattingItemView.swift
//  Vodam
//
//  Created by 이건준 on 11/19/25.
//

import SwiftUI

struct ChattingItemView: View {
    let chattingInfo: ChattingInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(chattingInfo.title)
                    .font(AppFont.pretendardBold(size: 18))
            }
            HStack{
                Text(chattingInfo.content)
                    .font(AppFont.pretendardRegular(size: 15))
            }
            HStack{
                Spacer()
                VStack{
                    Text(chattingInfo.formattedDate)
                        .font(AppFont.pretendardSemiBold(size: 13))
                }
            }
        }
        .frame(height: 77)
        .padding(.init(top: 15, leading: 9, bottom: 8, trailing: 9))
    }
}
