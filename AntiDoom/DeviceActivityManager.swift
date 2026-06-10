//  DeviceActivityManager.swift
//  Kapselt das Starten/Stoppen der DeviceActivity-Überwachung für die eine
//  Blockier-Regel: ein gemeinsames Event mit Minuten-Schwelle über einen
//  täglich wiederholenden Zeitplan.

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

enum DeviceActivityManager {
    static let activityName = DeviceActivityName("antidoom.daily")
    static let eventName = DeviceActivityEvent.Name("antidoom.limitReached")

    /// Startet die Überwachung. Stoppt zuerst eine evtl. laufende Instanz, damit
    /// Re-Konfiguration sauber neu aufsetzt (siehe Re-Arm-Risiko im Spec, Abschnitt C).
    static func start(selection: FamilyActivitySelection, limitMinutes: Int) throws {
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: limitMinutes)
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([activityName])
        try center.startMonitoring(activityName, during: schedule, events: [eventName: event])
    }

    /// Stoppt die Überwachung und löscht das Schild (benannter Store — identisch
    /// zu dem, den die Extension beschreibt).
    static func stop() {
        DeviceActivityCenter().stopMonitoring([activityName])
        BlockRuleStore.managedStore.clearAllSettings()
    }
}
