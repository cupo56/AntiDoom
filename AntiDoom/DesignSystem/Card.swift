//  Card.swift
//  Rounded surface container with a hairline border (no heavy shadow).

import SwiftUI

struct Card<Content: View>: View {
    private let padded: Bool
    private let content: Content

    init(padded: Bool = true, @ViewBuilder content: () -> Content) {
        self.padded = padded
        self.content = content()
    }

    var body: some View {
        content
            .padding(padded ? Theme.Spacing.m : 0)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
}

#Preview {
    Card {
        Text("Inhalt").font(Theme.Fonts.body()).foregroundStyle(Theme.Colors.ink)
    }
    .padding()
    .background(Theme.Colors.canvas)
}
