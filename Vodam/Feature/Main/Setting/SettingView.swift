import ComposableArchitecture
import PhotosUI
import SwiftData
import SwiftUI

struct SettingView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @State private var selectedItem: PhotosPickerItem?
    @State private var showDeleteConfirmation = false
    
    @Environment(\.modelContext) private var modelContext
    @Dependency(\.projectLocalDataClient) private var projectLocalDataClient
    @Dependency(\.fileCloudClient) private var fileCloudClient
    
    private var user: User? {
        store.user
    }
    
    var body: some View {
        List {
            profileSection
            userInfoSection
            accountSection
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .alert($store.scope(state: \.alert, action: \.alert))
        .onChange(of: selectedItem) { _, newItem in
            store.send(.photoPickerItemChanged(newItem))
        }
        .sheet(
            isPresented: Binding(
                get: { store.isShowingAppleDisconnectGuide },
                set: { isPresented in
                    if !isPresented {
                        store.send(.appleDisconnectGuideDismissed)
                    }
                }
            )
        ) {
            AppleDisconnectGuideView(
                onOpenSettings: {
                    store.send(.appleDisconnectGuideOpenSettingsButtonTapped)
                },
                onCompleted: {
                    store.send(.appleDisconnectGuideCompletedButtonTapped)
                }
            )
        }
        .task(id: store.pendingDeleteOwnerId) {
            // pendingDeleteOwnerId가 설정되면 로컬 데이터 삭제
            if let ownerId = store.pendingDeleteOwnerId {
                await deleteLocalData(ownerId: ownerId)
            }
        }
        .task(id: store.pendingLogoutOwnerId) {
            // pendingLogoutOwnerId가 설정되면 로컬 데이터 삭제 (로그아웃)
            if let ownerId = store.pendingLogoutOwnerId {
                await deleteLocalDataForLogout(ownerId: ownerId)
            }
        }
    }
    
    // MARK: - 로컬 데이터 삭제
    private func deleteLocalData(ownerId: String) async {
        do {
            let projects = try projectLocalDataClient.fetchAll(modelContext, ownerId)
            
            print("탈퇴 처리 시작: \(ownerId), 프로젝트 \(projects.count)개")
            
            // Storage 삭제
            for project in projects {
                if let remotePath = project.remoteAudioPath,
                   !remotePath.isEmpty,
                   (project.category == .audio || project.category == .file || project.category == .pdf) {
                    do {
                        try await fileCloudClient.deleteFile(remotePath)
                        print("Storage 파일 삭제: \(project.name)")
                    } catch {
                        print("Storage 파일 삭제 실패: \(project.name) - \(error)")
                        // 실패해도 계속 진행
                    }
                }
            }
            
            // 로컬 삭제
            try projectLocalDataClient.deleteAllForOwner(modelContext, ownerId)
            
            store.send(.localDataDeleted(ownerId))
            print("로컬 데이터 삭제 완료: \(ownerId)")
            
        } catch {
            print("로컬 데이터 삭제 실패: \(error)")
        }
    }
    
    // MARK: - 로그아웃 시 로컬 데이터 삭제
    private func deleteLocalDataForLogout(ownerId: String) async {
        do {
            print("로그아웃 - 로컬 데이터 삭제 시작: \(ownerId)")
            
            // 로컬 SwiftData만 삭제 (Firebase Storage는 유지)
            try projectLocalDataClient.deleteAllForOwner(modelContext, ownerId)
            
            print("로그아웃 - 로컬 데이터 삭제 완료: \(ownerId)")
            
        } catch {
            print("로그아웃 - 로컬 데이터 삭제 실패: \(error)")
        }
    }
    
    @ViewBuilder
    private var profileSection: some View {
        Section {
            HStack {
                Spacer()
                
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ProfileImageView(
                        user: user,
                        size: 80,
                        cornerRadius: 24,
                        showEditButton: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(user == nil)
                
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var userInfoSection: some View {
        Section {
            HStack {
                Image(systemName: "person.circle")
                Text("이름")
                Spacer()
                Text(user?.name ?? "게스트")
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "envelope.circle")
                Text("이메일")
                Spacer()
                if let email = user?.email {
                    Text(email)
                        .foregroundColor(.secondary)
                } else {
                    Text(user != nil ? "이메일 없음" : "비로그인")
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "exclamationmark.circle")
                Text("개인정보처리방침")
            }
            .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "questionmark.circle")
                Text("문의하기")
            }
            .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let user = user {
                Button {
                    store.send(.logoutTapped)
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("로그아웃")
                        Spacer()
                        Text(providerText(user.provider))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .foregroundStyle(.primary)
                
                Button {
                    store.send(.deleteAccountTapped)
                } label: {
                    HStack {
                        Image(systemName: "trash.circle")
                        Text("계정 삭제")
                            .foregroundColor(.red)
                    }
                }
                .foregroundStyle(.primary)
            } else {
                Button {
                    store.send(.loginButtonTapped)
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("로그인")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }
}

private func providerText(_ provider: AuthProvider) -> String {
    switch provider {
    case .apple: return "Apple"
    case .google: return "Google"
    case .kakao: return "Kakao"
    }
}
