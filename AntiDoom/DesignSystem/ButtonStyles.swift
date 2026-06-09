//  ButtonStyles.swift
//  Primary (filled sage) and secondary (muted text) button styles.

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(15, weight: .semibold))
            .foregroundStyle(Theme.Colors.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(13))
            .foregroundStyle(Theme.Colors.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

#Preview {
    VStack(spacing: 16) {
        Button("Schließen") {}.buttonStyle(.primary)
        Button("2 Minuten verlängern") {}.buttonStyle(.secondary)
    }
    .padding()
    .background(Theme.Colors.canvas)
}
