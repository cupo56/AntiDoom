//  BreathingRing.swift
//  The recurring brand motif: a thin sage ring with optional centered content.
//  (Breathing animation is intentionally deferred — see visual concept spec.)

import SwiftUI

struct BreathingRing<Content: View>: View {
    private let size: CGFloat
    private let lineWidth: CGFloat
    private let content: Content

    init(size: CGFloat = 116, lineWidth: CGFloat = 2, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.size = size
        self.lineWidth = lineWidth
        self.content = content()
    }

    var body: some View {
        Circle()
            .stroke(Theme.Colors.accent, lineWidth: lineWidth)
            .frame(width: size, height: size)
            .overlay { content }
    }
}

#Preview {
    BreathingRing {
        VStack(spacing: 2) {
            Text("4").font(Theme.Fonts.display(34)).foregroundStyle(Theme.Colors.ink)
            Text("LEVEL").font(Theme.Fonts.label()).tracking(1).foregroundStyle(Theme.Colors.inkMuted)
        }
    }
    .padding()
    .background(Theme.Colors.canvas)
}
