//  ContentView.swift
//  AntiDoom

import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var errorMessage: String?

    var body: some View {
        if isApproved {
            BlockRuleView()
        } else {
            authorizationGate
        }
    }

    private var authorizationGate: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()

            BreathingRing(size: 96) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Theme.Colors.accent)
            }

            Text("AntiDoom")
                .font(Theme.Fonts.display(32))
                .foregroundStyle(Theme.Colors.ink)

            Text(statusText)
                .font(Theme.Fonts.body(16, weight: .semibold))
                .foregroundStyle(Theme.Colors.inkMuted)

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Colors.danger)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Berechtigung anfragen") {
                Task { await requestAuthorization() }
            }
            .buttonStyle(.primary)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas)
        .onAppear { status = AuthorizationCenter.shared.authorizationStatus }
    }

    private var isApproved: Bool {
        status == .approved || status == .approvedWithDataAccess
    }

    private var statusText: String {
        switch status {
        case .notDetermined: return "Berechtigung noch nicht erteilt"
        case .denied: return "Berechtigung verweigert"
        case .approved, .approvedWithDataAccess: return "Berechtigung erteilt ✓"
        @unknown default: return "Unbekannter Status"
        }
    }

    private func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            errorMessage = nil
        } catch {
            errorMessage = "Anfrage fehlgeschlagen: \(error.localizedDescription)"
        }
        status = AuthorizationCenter.shared.authorizationStatus
    }
}

#Preview("Hell") {
    ContentView().preferredColorScheme(.light)
}

#Preview("Dunkel") {
    ContentView().preferredColorScheme(.dark)
}
