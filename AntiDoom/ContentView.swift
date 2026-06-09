//  ContentView.swift
//  AntiDoom

import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("AntiDoom")
                .font(.largeTitle.bold())

            Text(statusText)
                .font(.headline)
                .foregroundStyle(statusColor)

            if !isApproved {
                Button("Berechtigung anfragen") {
                    Task { await requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
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

    private var statusColor: Color {
        switch status {
        case .approved, .approvedWithDataAccess: return .green
        case .denied: return .red
        default: return .secondary
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

#Preview {
    ContentView()
}
