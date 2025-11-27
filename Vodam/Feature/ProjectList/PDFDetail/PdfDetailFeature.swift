//
//  PdfDetailFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/19/25.
//

//import ComposableArchitecture
//
//// TODO: 실제 프로젝트 상세 화면 Feature로 교체해야 합니다.
//@Reducer
//struct PdfDetailFeature {
//    @ObservableState
//    struct State: Equatable {
//        let project: Project
//        var isFavorite: Bool
//        
//        init(project: Project) {
//            self.project = project
//            self.isFavorite = project.isFavorite
//        }
//    }
//    
//    enum Action {
//        case favoriteButtonTapped
//        case editTitleButtonTapped
//        case deleteProjectButtonTapped
//        
//    }
//    
//    var body: some Reducer<State, Action> {
//        Reduce { state, action in
//            switch action {
//            case .favoriteButtonTapped:
//                state.isFavorite.toggle()
//                // TODO: 즐겨찾기 상태 저장 로직
//                return .none
//                
//            case .editTitleButtonTapped:
//                // TODO: 제목 수정 로직
//                return .none
//                
//            case .deleteProjectButtonTapped:
//                // TODO: 삭제 로직 (Alert 표시)
//                return .none
//            }
//        }
//    }
//}
