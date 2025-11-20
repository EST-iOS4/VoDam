//
//  PdfDetailView.swift
//  Vodam
//
//  Created by 서정원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI

struct PdfDetailView: View {
    @Bindable var store: StoreOf<PdfDetailFeature>
    var body: some View {
        Text("PdfDetailView")
    }
}
