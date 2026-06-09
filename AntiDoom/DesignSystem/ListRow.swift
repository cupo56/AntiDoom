//  ListRow.swift
//  Single row for lists inside a Card: optional leading SF Symbol, title,
//  optional trailing accent text.

import SwiftUI

struct ListRow: View {
    private let icon: String?
    private let title: String
    private let trailing: String?

    init(icon: String? = nil, title: String, trailing: String? = nil) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 30, height: 30)
            }
            Text(title)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }
}

#Preview {
    Card(padded: false) {
        VStack(spacing: 0) {
            ListRow(icon: "camera", title: "Instagram", trailing: "15 Min/Tag")
            Divider().overlay(Theme.Colors.border)
            ListRow(icon: "music.note", title: "TikTok", trailing: "10 Min/Tag")
        }
    }
    .padding()
    .background(Theme.Colors.canvas)
}
