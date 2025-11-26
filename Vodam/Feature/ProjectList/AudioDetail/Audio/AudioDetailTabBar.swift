//
//  AudioDetailTabBar.swift
//  Vodam
//
//  Created by 서정원 on 11/22/25.
//

import SwiftUI

struct AudioDetailTabBar: View {
    @Binding var selectedTab: Tab
    
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack {
                        Text(tab.title)
                            .font(.headline)
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        
                        if selectedTab == tab {
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.primary)
                        } else {
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(.clear)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}
