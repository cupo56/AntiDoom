//  SectionLabel.swift
//  Micro uppercase label, e.g. "GESCHÜTZTE APPS".

import SwiftUI

struct SectionLabel: View {
    private let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.Fonts.label())
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.inkMuted)
    }
}

#Preview {
    SectionLabel("Geschützte Apps")
        .padding()
        .background(Theme.Colors.canvas)
}
