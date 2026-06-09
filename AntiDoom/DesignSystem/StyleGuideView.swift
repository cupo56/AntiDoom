//  StyleGuideView.swift
//  Living documentation: shows every design-system token and component on the
//  canvas, in both light and dark previews. Not wired into the app's navigation.

import SwiftUI

struct StyleGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {

                Text("Bringt dir das gerade wirklich etwas?")
                    .font(Theme.Fonts.display(25))
                    .foregroundStyle(Theme.Colors.ink)

                Text("Atme einmal durch. Nenne 3 Dinge, die du gerade um dich herum siehst.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.inkMuted)

                BreathingRing {
                    VStack(spacing: 2) {
                        Text("4").font(Theme.Fonts.display(34)).foregroundStyle(Theme.Colors.ink)
                        Text("LEVEL").font(Theme.Fonts.label()).tracking(1).foregroundStyle(Theme.Colors.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionLabel("Geschützte Apps")
                    Card(padded: false) {
                        VStack(spacing: 0) {
                            ListRow(icon: "camera", title: "Instagram", trailing: "15 Min/Tag")
                            Divider().overlay(Theme.Colors.border)
                            ListRow(icon: "music.note", title: "TikTok", trailing: "10 Min/Tag")
                            Divider().overlay(Theme.Colors.border)
                            ListRow(icon: "play.rectangle", title: "YouTube", trailing: "20 Min/Tag")
                        }
                    }
                }

                Card {
                    Text("Eine Karte mit Inhalt.")
                        .font(Theme.Fonts.body())
                        .foregroundStyle(Theme.Colors.ink)
                }

                VStack(spacing: Theme.Spacing.xs) {
                    Button("Schließen") {}.buttonStyle(.primary)
                    Button("2 Minuten verlängern") {}.buttonStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .background(Theme.Colors.canvas)
    }
}

#Preview("Hell") {
    StyleGuideView().preferredColorScheme(.light)
}

#Preview("Dunkel") {
    StyleGuideView().preferredColorScheme(.dark)
}
