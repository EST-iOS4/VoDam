//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftData
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>

    @Environment(\.modelContext) private var modelContext
    @Dependency(\.firebaseClient) private var firebaseClient

    init(store: StoreOf<MainFeature>) {
        self.store = store
    }

    var body: some View {
        VStack {
            RecordingView(
                store: store.scope(
                    state: \.recording,
                    action: \.recording
                ),
                ownerId: store.currentUser?.ownerId
            )
            FileButtonView(
                store: store.scope(
                    state: \.fileButton,
                    action: \.fileButton
                )
            )

            PDFButtonView(
                store: store.scope(
                    state: \.pdfButton,
                    action: \.pdfButton
                )
            )
            Spacer()
        }
        .navigationTitle("새 프로젝트 생성")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.profileButtonTapped)
                } label: {
                    if store.currentUser != nil {
                        ProfileImageView(
                            user: store.currentUser,
                            size: 36,
                            cornerRadius: 18,
                            showEditButton: false
                        )
                    } else {
                        Image(systemName: "person.circle")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationDestination(
            store: store.scope(
                state: \.$loginProviders,
                action: \.loginProviders
            )
        ) {
            loginProvidersStore in
            LoginProvidersView(store: loginProvidersStore)
        }

        .sheet(
            store: store.scope(
                state: \.$profileFlow,
                action: \.profileFlow
            )
        ) { profileStore in
            ProfileFlowView(store: profileStore)
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }

        .navigationDestination(
            store: store.scope(
                state: \.$settings,
                action: \.settings
            )
        ) {
            settingStore in
            SettingView(store: settingStore)
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: store.currentUser) { oldValue, newValue in
            guard let user = newValue else { return }

            let ownerId = user.ownerId

            Task {
                do {
                    let descriptor = FetchDescriptor<RecordingModel>(
                        predicate: #Predicate { recording in
                            recording.ownerId == nil
                                && recording.syncStatusRaw
                                    == "localOnly"
                        }
                    )

                    let guestRecordings = try modelContext.fetch(descriptor)

                    guard !guestRecordings.isEmpty else {
                        print("마이그레이션 대상 게스트 녹음 없음")
                        return
                    }

                    print("🔥 마이그레이션 대상 게스트 녹음 개수: \(guestRecordings.count)")

                    let payloads = guestRecordings.map(
                        RecordingPayload.init(model:)
                    )

                    try await firebaseClient.uploadRecordings(ownerId, payloads)

                    for recording in guestRecordings {
                        recording.ownerId = ownerId
                        recording.syncStatus = .synced
                    }

                    try modelContext.save()
                    print(
                        "게스트 녹음 \(guestRecordings.count)개 Firebase 업로드 및 SwiftData 마이그레이션 완료"
                    )

                } catch {
                    print("게스트 → 로그인 마이그레이션 실패: \(error)")
                }
            }
        }
    }
}
