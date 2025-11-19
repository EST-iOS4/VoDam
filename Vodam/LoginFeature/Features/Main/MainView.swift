//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct MainView: View { //MainView에서 사용하는 store 객체는 MainFeature
    let store: StoreOf<MainFeature>  // MainFeature.Action

    var body: some View {
        VStack { // 화면 세로 배치, 항상 가운데 정렬
                // 녹음 버튼, 파일 가져오기 버튼, PDF 가져오기 버튼
            
            RecordingView( // RecordingView stae, action을 store
                            store: store.scope(
                                state: \.recording,
                                action: \.recording
                            )
                        )
            // MARK: - 파일 가져오기
                       FileButtonView(
                           store: store.scope(
                               state: \.fileButton,
                               action: \.fileButton
                           )
                       )

                       // MARK: - PDF 가져오기
                       PDFButtonView(
                           store: store.scope(
                               state: \.pdfButton,
                               action: \.pdfButton
                           )
                       )

            Spacer()
            
//            Text("여기에 메인 UI 들어갈 예정")
//                .font(.title3)
//                .foregroundStyle(.secondary)

        }
        .navigationTitle("새 프로젝트 생성") //네비게이션 상단 제목
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { //toolbar/toolbaritem
                Button {
                    store.send(.profileButtonTapped) //Button 탭을 store 전달
                } label: {
                    Image(systemName: "person.circle")
                        .imageScale(.large)
                }
            }
        }

        .navigationDestination( // 특정 상태가 존재할 때 다음 화면으로 이동하게 하는 TCA 문법
            store: store.scope( // MainFeature
                state: \.$loginProviders,
                action: \.loginProviders
            )
        ) {
            loginProvidersStore in
            LoginProvidersView(store: loginProvidersStore)
        }
        // 로그인 유도 sheet
        .sheet(
            store: store.scope(
                state: \.$profileFlow,
                action: \.profileFlow
            )
        ) { profileStore in //profileFlow에 전달되는 store
            ProfileFlowView(store: profileStore)
                .presentationDetents([.fraction(0.4)]) // sheet 높이를 화면 40%로 지정
                .presentationDragIndicator(.visible) // sheet 상단 드래그 표시 보이기
        }
    }
}
