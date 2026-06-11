//  ShieldActionExtension.swift
//  Behandelt Button-Drücke: Stage 0 → .defer (zweiter Screen), Stage 1 →
//  Zugang gewähren + Nutzungsfenster scharf stellen, Sekundär → beenden.

import DeviceActivity
import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(resolve(action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(resolve(action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(resolve(action))
    }

    private func resolve(_ action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            if ReflectionStore.effectiveStage == 0 {
                // Screen 0 → Screen 1: Schild neu rendern lassen.
                ReflectionStore.setStage(1)
                return .defer
            } else {
                grantWindow()
                return .close
            }
        case .secondaryButtonPressed:
            ReflectionStore.appendLog(outcome: .exited)
            ReflectionStore.setStage(0)
            return .close
        @unknown default:
            return .close
        }
    }

    /// Gibt alle Apps des gemeinsamen Kontingents frei und stellt das
    /// 5-Min-Nutzungsfenster scharf (Re-Block via Monitor).
    private func grantWindow() {
        BlockRuleStore.managedStore.shield.applications = nil
        try? DeviceActivityManager.startEarnedWindow(selection: BlockRuleStore.selection)
        ReflectionStore.appendLog(outcome: .extended)
        ReflectionStore.setStage(0)
    }
}
