//
//  AppleDisconnectGuideView.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import SwiftUI

struct AppleDisconnectGuideView: View {
    let onOpenSettings: () -> Void
    let onCompleted: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Apple 계정과 Vodam 완전 해제")
                    .font(.title2)
                    .bold()

                Text(
                    """
                    1. iPhone의 설정 앱을 엽니다.
                    2. 맨 위의 Apple ID(본인 이름)를 탭합니다.
                    3. [Apple로 로그인] 선택합니다.
                    4. 목록에서 [Vodam iOS App]을 선택합니다.
                    5. [삭제] 선택 -> 사용 중단을 탭합니다.
                    6. Vodam으로 돌아와서 과정 완료 버튼 탭합니다.
                    """
                )
                .font(.subheadline)

                Spacer()

                Button("설정 열기") {
                    onOpenSettings()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                Button("위 과정을 완료했어요. Vodam 계정을 탈퇴할게요") {
                    onCompleted()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("애플 계정 해제 안내")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
