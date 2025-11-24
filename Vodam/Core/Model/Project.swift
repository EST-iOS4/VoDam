//
//  Project.swift
//  Vodam
//
//  Created by 이건준 on 11/24/25.
//

import Foundation
import IdentifiedCollections

struct Project: Hashable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var creationDate: Date
    var category: Category
    var isFavorite: Bool
    
    static let mock: IdentifiedArrayOf<Project> = [
        Project(id: UUID(), name: "파일로 저장된 프로젝트", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 19)) ?? Date(), category: .file, isFavorite: false),
        Project(id: UUID(), name: "PDF로 저장된 프로젝트", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 18)) ?? Date(), category: .pdf, isFavorite: false),
        Project(id: UUID(), name: "저장된 프로젝트1", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 17)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "2025저장된 프로젝트", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 4, day: 17)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "ㅁㄴㅇㅁㄴㅇ", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 17)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "121124", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 17)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "7", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 16)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "8", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 16)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "9", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 9, day: 16)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "10", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 16)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "11", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 16)) ?? Date(), category: .audio, isFavorite: false),
        Project(id: UUID(), name: "12", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 16)) ?? Date(), category: .audio, isFavorite: false)
    ]
}
