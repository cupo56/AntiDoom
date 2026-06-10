//  DeviceActivityMonitorExtension.swift
//  Setzt beim Erreichen der Tagesschwelle das Schild über die ausgewählten Apps
//  und löscht es zu Beginn eines neuen Tages-Intervalls (Tages-Reset).

import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = BlockRuleStore.managedStore

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Neuer Tag: Schild zurücksetzen, damit die Apps wieder erreichbar sind.
        store.shield.applications = nil
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        // Tageslimit erreicht: Schild über die ausgewählten Apps legen.
        let tokens = BlockRuleStore.selection.applicationTokens
        store.shield.applications = tokens.isEmpty ? nil : tokens
    }
}
