//  BlockRuleView.swift
//  Funktional-minimaler Ein-Regel-Screen: Apps wählen, gemeinsames Tageslimit
//  setzen, Regel aktivieren/deaktivieren. Baut auf dem Design-System auf.

import SwiftUI
import FamilyControls

struct BlockRuleView: View {
    @State private var selection = BlockRuleStore.selection
    @State private var limitMinutes = BlockRuleStore.limitMinutes
    @State private var isActive = BlockRuleStore.isActive
    @State private var pickerPresented = false
    @State private var errorMessage: String?

    private var appCount: Int { selection.applicationTokens.count }
    private var canActivate: Bool { appCount > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                header

                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionLabel("Apps")
                        Text(appCount == 0 ? "Noch keine App gewählt"
                                           : "\(appCount) App\(appCount == 1 ? "" : "s") gewählt")
                            .font(Theme.Fonts.body(16))
                            .foregroundStyle(Theme.Colors.ink)
                        Button("Apps auswählen") { pickerPresented = true }
                            .buttonStyle(.secondary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionLabel("Tageslimit")
                        Stepper(value: $limitMinutes, in: 5...120, step: 5) {
                            Text("\(limitMinutes) Min/Tag")
                                .font(Theme.Fonts.body(16))
                                .foregroundStyle(Theme.Colors.ink)
                        }
                        .onChange(of: limitMinutes) { _, newValue in
                            BlockRuleStore.limitMinutes = newValue
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                }

                actionButton
                statusText
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas)
        .familyActivityPicker(isPresented: $pickerPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in
            BlockRuleStore.selection = newValue
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Blockier-Regel")
                .font(Theme.Fonts.display(28))
                .foregroundStyle(Theme.Colors.ink)
            Text("Ein gemeinsames Tageslimit über deine gewählten Apps.")
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.l)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isActive {
            Button("Deaktivieren") { deactivate() }
                .buttonStyle(.secondary)
        } else {
            Button("Aktivieren") { activate() }
                .buttonStyle(.primary)
                .disabled(!canActivate)
        }
    }

    private var statusText: some View {
        Text(isActive ? "Aktiv — Limit wird überwacht ✓" : "Inaktiv")
            .font(Theme.Fonts.body(14, weight: .semibold))
            .foregroundStyle(isActive ? Theme.Colors.accent : Theme.Colors.inkMuted)
    }

    private func activate() {
        BlockRuleStore.selection = selection
        BlockRuleStore.limitMinutes = limitMinutes
        do {
            try DeviceActivityManager.start(selection: selection, limitMinutes: limitMinutes)
            BlockRuleStore.isActive = true
            isActive = true
            errorMessage = nil
        } catch {
            errorMessage = "Aktivierung fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func deactivate() {
        DeviceActivityManager.stop()
        BlockRuleStore.isActive = false
        isActive = false
        errorMessage = nil
    }
}

#Preview("Hell") {
    BlockRuleView().preferredColorScheme(.light)
}

#Preview("Dunkel") {
    BlockRuleView().preferredColorScheme(.dark)
}
