//  ReflectionStore.swift
//  Geteilter Zustand des Reflexions-Erlebnisses (Stage, aktueller Prompt,
//  Reflexions-Log) in den App-Group-UserDefaults — gelesen/geschrieben von der
//  ShieldConfiguration-, ShieldAction- und Monitor-Extension.

import Foundation

enum ReflectionOutcome: String, Codable {
    case extended
    case exited
}

enum ReflectionStore {
    static let windowUsageMinutes = 5

    /// Beruhigend-erdende Prompts (Screen 0).
    static let prompts: [String] = [
        "Du musst gerade nichts. Atme.",
        "Dieser Moment gehört dir, nicht dem Feed.",
        "Spür kurz deinen Atem, bevor du weitergehst.",
        "Es ist okay, einfach hier zu sein.",
        "Nichts da drin braucht dich gerade dringend."
    ]

    /// Wie lange eine angefangene Stufe gültig bleibt (Staleness-Guard).
    private static let stageStaleness: TimeInterval = 120

    private static let stageKey = "reflection.stage"
    private static let stageSetAtKey = "reflection.stageSetAt"
    private static let promptIndexKey = "reflection.promptIndex"
    private static let logKey = "reflection.log"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: BlockRuleStore.appGroupID) ?? .standard
    }

    /// Aktueller Prompt-Text für das Schild.
    static var currentPrompt: String {
        let index = defaults.object(forKey: promptIndexKey) as? Int ?? 0
        return prompts.indices.contains(index) ? prompts[index] : prompts[0]
    }

    /// Stage mit Staleness-Guard: eine über `stageStaleness` alte Stufe > 0 gilt als 0.
    static var effectiveStage: Int {
        let stage = defaults.integer(forKey: stageKey)
        guard stage > 0 else { return 0 }
        let setAt = defaults.object(forKey: stageSetAtKey) as? Date ?? .distantPast
        return Date().timeIntervalSince(setAt) > stageStaleness ? 0 : stage
    }

    /// Setzt die Stufe und merkt sich den Zeitpunkt.
    static func setStage(_ stage: Int) {
        defaults.set(stage, forKey: stageKey)
        defaults.set(Date(), forKey: stageSetAtKey)
    }

    /// Neue Schild-Episode: frischer Zufalls-Prompt, Stufe zurück auf 0.
    static func beginShieldEpisode() {
        defaults.set(Int.random(in: prompts.indices), forKey: promptIndexKey)
        setStage(0)
    }

    /// Hängt einen Reflexions-Ausgang an das Log an.
    static func appendLog(outcome: ReflectionOutcome) {
        let index = defaults.object(forKey: promptIndexKey) as? Int ?? 0
        var entries = (try? JSONDecoder().decode([LogEntry].self,
                       from: defaults.data(forKey: logKey) ?? Data())) ?? []
        entries.append(LogEntry(promptIndex: index, outcome: outcome, timestamp: Date()))
        defaults.set(try? JSONEncoder().encode(entries), forKey: logKey)
    }

    struct LogEntry: Codable {
        let promptIndex: Int
        let outcome: ReflectionOutcome
        let timestamp: Date
    }
}
