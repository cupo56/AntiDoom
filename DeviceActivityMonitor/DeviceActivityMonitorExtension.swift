//  DeviceActivityMonitorExtension.swift
//  Tageslimit ODER abgelaufenes Nutzungsfenster → Schild (neu) setzen und eine
//  frische Reflexions-Episode beginnen. Tages-Reset bei Intervallstart.

import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = BlockRuleStore.managedStore

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Neuer Tag (antidoom.daily um Mitternacht): Schild zurücksetzen.
        if activity == DeviceActivityManager.activityName {
            store.shield.applications = nil
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        // Tageslimit erreicht ODER Nutzungsfenster aufgebraucht: Schild setzen.
        let tokens = BlockRuleStore.selection.applicationTokens
        store.shield.applications = tokens.isEmpty ? nil : tokens
        ReflectionStore.beginShieldEpisode()
        if activity == DeviceActivityManager.windowActivityName {
            DeviceActivityManager.stopEarnedWindow()
        }
    }
}
