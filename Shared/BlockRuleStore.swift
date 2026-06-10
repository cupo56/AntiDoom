//  BlockRuleStore.swift
//  Persistiert die eine Blockier-Regel (App-Auswahl + Limit + aktiv) in den
//  geteilten App-Group-UserDefaults, damit App und DeviceActivityMonitor-
//  Extension dieselbe Regel sehen. Hält außerdem die geteilten Konstanten.

import Foundation
import FamilyControls
import ManagedSettings

enum BlockRuleStore {
    /// Geteilte App Group (identisch zu SharedStore.appGroupID).
    static let appGroupID = "group.antidoom.AntiDoom"

    /// Name des benannten ManagedSettingsStore. LOAD-BEARING: Extension (setzt
    /// das Schild) und App (löscht es beim Deaktivieren) MÜSSEN denselben Namen
    /// verwenden, sonst entfernt "Deaktivieren" das Schild still nicht.
    static let managedStoreName = "antidoom"

    private static let selectionKey = "blockRule.selection"
    private static let limitMinutesKey = "blockRule.limitMinutes"
    private static let isActiveKey = "blockRule.isActive"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Der benannte Store, über den das Schild gesetzt/gelöscht wird.
    static var managedStore: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: managedStoreName))
    }

    /// Ausgewählte Apps (nur App-Tokens werden genutzt; Kategorien/Web-Domains ignoriert).
    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: selectionKey),
                  let value = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return value
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: selectionKey)
        }
    }

    /// Gemeinsames Tageslimit in Minuten (Default 30).
    static var limitMinutes: Int {
        get { defaults.object(forKey: limitMinutesKey) as? Int ?? 30 }
        set { defaults.set(newValue, forKey: limitMinutesKey) }
    }

    /// Ob die Regel aktiv überwacht wird.
    static var isActive: Bool {
        get { defaults.bool(forKey: isActiveKey) }
        set { defaults.set(newValue, forKey: isActiveKey) }
    }
}
