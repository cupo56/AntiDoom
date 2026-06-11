//  DeviceActivityManager.swift
//  Kapselt das Starten/Stoppen der DeviceActivity-Überwachung: die tägliche
//  Blockier-Regel (TP2) und das zurückgewonnene Nutzungsfenster (TP3).

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

enum DeviceActivityManager {
    static let activityName = DeviceActivityName("antidoom.daily")
    static let eventName = DeviceActivityEvent.Name("antidoom.limitReached")
    static let windowActivityName = DeviceActivityName("antidoom.window")
    static let windowEventName = DeviceActivityEvent.Name("antidoom.windowReached")

    /// Startet die tägliche Überwachung. Stoppt zuerst eine evtl. laufende Instanz.
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

    /// Stoppt die tägliche Überwachung und löscht das Schild.
    static func stop() {
        DeviceActivityCenter().stopMonitoring([activityName])
        BlockRuleStore.managedStore.clearAllSettings()
    }

    /// Startet das zurückgewonnene Nutzungsfenster: feuert nach
    /// `ReflectionStore.windowUsageMinutes` echter Nutzung erneut.
    /// `intervalStart = jetzt`, damit die heute bereits verbrauchte Nutzung NICHT
    /// mitzählt (sonst würde der Schwellwert sofort feuern).
    static func startEarnedWindow(selection: FamilyActivitySelection) throws {
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(minute: ReflectionStore.windowUsageMinutes)
        )
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let schedule = DeviceActivitySchedule(
            intervalStart: now,
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([windowActivityName])
        try center.startMonitoring(windowActivityName, during: schedule, events: [windowEventName: event])
    }

    /// Stoppt das Nutzungsfenster (nach Re-Block).
    static func stopEarnedWindow() {
        DeviceActivityCenter().stopMonitoring([windowActivityName])
    }
}
