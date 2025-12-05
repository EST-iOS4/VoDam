//
//  AudioDetailTabBar.swift
//  Vodam
//
//  Created by 서정원 on 11/22/25.
//

import SwiftUI

struct AudioDetailTabBar: View {
    @Binding var selectedTab: AudioDetailFeature.Tab
    
    var body: some View {
        HStack(spacing: 0){
            ForEach(AudioDetailFeature.Tab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font( AppFont.pretendardSemiBold(size: 17))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedTab == tab ? AppColor.mainColor : Color.clear)
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding()
    }
}
