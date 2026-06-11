# Reflexions-Erlebnis (Teilprojekt 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Statt des System-„Restricted" erscheint ein gestuftes, gebrandetes Reflexions-Schild; bewusstes Durchgehen gibt 5 Minuten Nutzungszeit zurück, jede Entscheidung wird protokolliert.

**Architecture:** Neuer `ShieldAction`-Extension-Target behandelt Button-Drücke: Stage 0 → `.defer` (Schild rendert Screen 2 neu), Stage 1 → Schild löschen + 5-Min-Nutzungsfenster über `DeviceActivityEvent`-Schwelle (TP2-Mechanismus) scharf stellen. Geteilter `ReflectionStore` (App-Group-UserDefaults) hält Stage/Prompt/Log; `DeviceActivityManager` wandert nach `Shared/`, weil App, ShieldAction und Monitor ihn brauchen.

**Tech Stack:** Swift, ManagedSettings/ManagedSettingsUI (ShieldAction + ShieldConfiguration), DeviceActivity, FamilyControls, App-Group-UserDefaults, `xcodeproj`-Ruby-Gem.

**Spec:** `docs/superpowers/specs/2026-06-11-reflexions-erlebnis-design.md`

---

## Wichtig: Verifizierung in diesem Projekt

Es gibt **kein Unit-Test-Target**. Autonomer Gate ist der Simulator-Compile:

```bash
./scripts/build-sim.sh
```

Erfolg = Endzeile `** BUILD SUCCEEDED **`. Keine Kernfunktion (Schild, `.defer`, Re-Block) ist im Simulator testbar — jeder Task endet mit `build-sim` + Commit; das Verhalten prüft der Nutzer auf dem Gerät (Task 6).

**Editor-Diagnostics** wie „unavailable in macOS" / „Cannot find … in scope" sind FALSCH-POSITIVE (iOS-only Frameworks, SourceKit indexiert macOS). Maßgeblich ist ALLEIN `build-sim`.

---

## File Structure

| Datei | Verantwortung | Neu/Ändern |
|---|---|---|
| `Shared/ReflectionStore.swift` | Stage + Prompt + Reflexions-Log (App-Group) | **Neu** |
| `Shared/DeviceActivityManager.swift` | Monitoring start/stop **inkl. Earned-Window** | **Verschoben** aus `AntiDoom/` + erweitert |
| `scripts/pbxproj/04_add_tp3_shared.rb` | wired die zwei Shared-Dateien in die bestehenden Targets | **Neu** |
| `ShieldAction/ShieldActionExtension.swift` | Button-Logik (gestuft, Unlock, Exit) | **Neu** (neuer Target) |
| `ShieldAction/Info.plist`, `ShieldAction/ShieldAction.entitlements` | Extension-Wiring | **Neu** |
| `ShieldConfiguration/ShieldConfigurationExtension.swift` | gebrandetes, gestuftes Schild + Ring-Icon | **Ändern** (Skelett füllen) |
| `DeviceActivityMonitor/DeviceActivityMonitorExtension.swift` | Window-Event → Re-Block + frische Episode | **Ändern** |
| `docs/superpowers/device-test-checklist-reflexions-erlebnis.md` | Geräte-Test | **Neu** |

`Shared/` ist ein manueller Group (braucht pbxproj-Skript). `ShieldAction/` wird von `add_extension.rb` als synchronisierter Target angelegt.

---

## Task 1: Shared-Schicht für TP3 (ReflectionStore + DeviceActivityManager-Move)

**Files:**
- Create: `Shared/ReflectionStore.swift`
- Move+Modify: `AntiDoom/DeviceActivityManager.swift` → `Shared/DeviceActivityManager.swift`
- Create: `scripts/pbxproj/04_add_tp3_shared.rb`

- [ ] **Step 1: `DeviceActivityManager` nach `Shared/` verschieben**

Run: `git mv AntiDoom/DeviceActivityManager.swift Shared/DeviceActivityManager.swift`

- [ ] **Step 2: `Shared/DeviceActivityManager.swift` um das Earned-Window erweitern**

Ersetze den GESAMTEN Inhalt durch:

```swift
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
```

- [ ] **Step 3: `Shared/ReflectionStore.swift` anlegen**

```swift
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
```

- [ ] **Step 4: pbxproj-Skript `scripts/pbxproj/04_add_tp3_shared.rb` anlegen**

```ruby
#!/usr/bin/env ruby
# Wired die TP3-Shared-Dateien in die bestehenden Targets:
#   ReflectionStore.swift      -> AntiDoom, DeviceActivityMonitor, ShieldConfiguration
#   DeviceActivityManager.swift -> AntiDoom, DeviceActivityMonitor
#     (NICHT ShieldConfiguration — die rendert nur, braucht kein DeviceActivity)
# Idempotent. ShieldAction bekommt beide später automatisch via add_extension.rb.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
group = project.main_group.find_subpath('Shared', true)
group.set_path('Shared')

add = lambda do |name, target_names|
  ref = group.files.find { |f| f.display_name == name } || group.new_reference(name)
  target_names.each do |tn|
    t = project.targets.find { |x| x.name == tn } or abort "#{tn} not found"
    already = t.source_build_phase.files.any? { |bf| bf.file_ref == ref }
    t.add_file_references([ref]) unless already
  end
end

add.call('ReflectionStore.swift', %w[AntiDoom DeviceActivityMonitor ShieldConfiguration])
add.call('DeviceActivityManager.swift', %w[AntiDoom DeviceActivityMonitor])

project.save
puts 'Wired TP3 shared sources into existing targets.'
```

- [ ] **Step 5: Skript ausführen**

Run: `ruby scripts/pbxproj/04_add_tp3_shared.rb`
Expected: `Wired TP3 shared sources into existing targets.`

- [ ] **Step 6: Compile-Gate** (App findet `DeviceActivityManager` jetzt über `Shared/`, Verhalten unverändert)

Run: `./scripts/build-sim.sh 2>&1 | tail -5`
Expected: endet mit `** BUILD SUCCEEDED **`. Bei echten Fehlern beheben, bis grün.

- [ ] **Step 7: Commit**

```bash
git checkout -- AntiDoom.xcodeproj/project.pbxproj 2>/dev/null
git add Shared/ReflectionStore.swift Shared/DeviceActivityManager.swift scripts/pbxproj/04_add_tp3_shared.rb AntiDoom.xcodeproj/project.pbxproj
git commit -m "feat(reflexion): ReflectionStore + DeviceActivityManager nach Shared (Earned-Window)"
```

---

## Task 2: `ShieldAction`-Target anlegen (Skelett, baut grün)

**Files:**
- Create: `ShieldAction/ShieldActionExtension.swift`
- Create: `ShieldAction/Info.plist`
- Create: `ShieldAction/ShieldAction.entitlements`

> Reihenfolge wie TP1: erst Target anlegen + grün bauen, dann Logik (Task 3).

- [ ] **Step 1: `ShieldAction/ShieldActionExtension.swift` (Skelett) anlegen**

```swift
//  ShieldActionExtension.swift
//  Behandelt Button-Drücke auf dem Schild. Logik folgt in Task 3.

import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
}
```

- [ ] **Step 2: `ShieldAction/Info.plist` anlegen**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>ShieldAction</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.ManagedSettings.shield-action-service</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).ShieldActionExtension</string>
	</dict>
</dict>
</plist>
```

- [ ] **Step 3: `ShieldAction/ShieldAction.entitlements` anlegen**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.family-controls</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.cupo.antidoom</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Target via `add_extension.rb` anlegen** (idempotent; bettet `.appex` ein, zieht alle `Shared/*.swift` ins Target)

Run: `ruby scripts/pbxproj/add_extension.rb ShieldAction com.cupo.antidoom.ShieldAction ShieldActionExtension`
Expected: `Added extension target ShieldAction and embedded it in AntiDoom.`

- [ ] **Step 5: Compile-Gate**

Run: `./scripts/build-sim.sh 2>&1 | tail -5`
Expected: endet mit `** BUILD SUCCEEDED **`. Falls Fehler (z.B. Delegate-Methodensignatur): die korrekte `ShieldActionDelegate`-API verwenden, bis grün.

- [ ] **Step 6: Commit**

```bash
git checkout -- AntiDoom.xcodeproj/project.pbxproj 2>/dev/null
git add ShieldAction/ AntiDoom.xcodeproj/project.pbxproj
git commit -m "feat(reflexion): ShieldAction-Target-Skelett (baut grün, embedded)"
```

---

## Task 3: ShieldAction-Logik (gestuft, Unlock, Exit)

**Files:**
- Modify: `ShieldAction/ShieldActionExtension.swift`

- [ ] **Step 1: Gesamten Inhalt durch die echte Logik ersetzen**

```swift
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
```

- [ ] **Step 2: Compile-Gate**

Run: `./scripts/build-sim.sh 2>&1 | tail -5`
Expected: endet mit `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git checkout -- AntiDoom.xcodeproj/project.pbxproj 2>/dev/null
git add ShieldAction/ShieldActionExtension.swift
git commit -m "feat(reflexion): ShieldAction-Logik — gestufte Reibung, Unlock, Exit"
```

---

## Task 4: Gebrandetes, gestuftes Schild + Ring-Icon

**Files:**
- Modify: `ShieldConfiguration/ShieldConfigurationExtension.swift`

- [ ] **Step 1: Gesamten Inhalt durch die gebrandete, gestufte Config ersetzen**

```swift
//  ShieldConfigurationExtension.swift
//  Gebrandetes, gestuftes Reflexions-Schild ("Ruhig & Minimal"). Stage und
//  Prompt kommen aus dem ReflectionStore; keine Seiteneffekte hier.

import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }
    override func configuration(
        shielding application: Application, in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }
    override func configuration(
        shielding webDomain: WebDomain, in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let stageZero = ReflectionStore.effectiveStage == 0
        let title = stageZero ? "Kurz innehalten" : "Atme dreimal tief durch"
        let subtitle = stageZero
            ? ReflectionStore.currentPrompt
            : "Langsam ein … und wieder aus. Wenn du bereit bist, geht es weiter."
        let primary = stageZero ? "Durchatmen" : "Ich bin bereit"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterial,
            backgroundColor: ShieldPalette.canvas,
            icon: ShieldPalette.ringIcon(),
            title: ShieldConfiguration.Label(text: title, color: ShieldPalette.ink),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: ShieldPalette.inkMuted),
            primaryButtonLabel: ShieldConfiguration.Label(text: primary, color: ShieldPalette.onAccent),
            primaryButtonBackgroundColor: ShieldPalette.accent,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Beenden", color: ShieldPalette.ink)
        )
    }
}

/// Spiegelt Theme.Colors (das SwiftUI-Design-System ist hier nicht importierbar).
/// Werte aus AntiDoom/DesignSystem/Theme.swift.
private enum ShieldPalette {
    static let canvas   = brand(light: 0xF4F2EC, dark: 0x141815)
    static let ink      = brand(light: 0x1D2A30, dark: 0xE9E7DF)
    static let inkMuted = brand(light: 0x8A948F, dark: 0x888F88)
    static let accent   = brand(light: 0x7E9B82, dark: 0x8FB093)
    static let onAccent = UIColor.white

    static func brand(light: UInt, dark: UInt) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        }
    }

    /// Statisches BreathingRing-Motiv: zwei konzentrische Sage-Kreise.
    static func ringIcon() -> UIImage {
        let size = CGSize(width: 80, height: 80)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let sage = accent.resolvedColor(with: UITraitCollection.current)
            sage.setStroke()
            let outer = CGRect(x: 8, y: 8, width: 64, height: 64)
            let p1 = UIBezierPath(ovalIn: outer); p1.lineWidth = 4; p1.stroke()
            let p2 = UIBezierPath(ovalIn: outer.insetBy(dx: 14, dy: 14)); p2.lineWidth = 3; p2.stroke()
        }
    }
}

private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
```

- [ ] **Step 2: Compile-Gate**

Run: `./scripts/build-sim.sh 2>&1 | tail -5`
Expected: endet mit `** BUILD SUCCEEDED **`. Falls die `ShieldConfiguration`-Initializer-Signatur abweicht: an die echte API anpassen (Reihenfolge der Labels/Farben), Struktur beibehalten.

- [ ] **Step 3: Commit**

```bash
git checkout -- AntiDoom.xcodeproj/project.pbxproj 2>/dev/null
git add ShieldConfiguration/ShieldConfigurationExtension.swift
git commit -m "feat(reflexion): gebrandetes, gestuftes Schild + Ring-Icon"
```

---

## Task 5: Monitor — Window-Event → Re-Block + frische Episode

**Files:**
- Modify: `DeviceActivityMonitor/DeviceActivityMonitorExtension.swift`

- [ ] **Step 1: Gesamten Inhalt ersetzen**

```swift
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
```

> Hinweis: `intervalDidStart` löscht jetzt nur noch beim **Tages**-Intervall (vorher unbedingt). Das Fenster-Intervall (`antidoom.window`, `intervalStart = jetzt`) soll das während des Fensters bereits gelöschte Schild NICHT versehentlich beeinflussen.

- [ ] **Step 2: Compile-Gate**

Run: `./scripts/build-sim.sh 2>&1 | tail -5`
Expected: endet mit `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git checkout -- AntiDoom.xcodeproj/project.pbxproj 2>/dev/null
git add DeviceActivityMonitor/DeviceActivityMonitorExtension.swift
git commit -m "feat(reflexion): Monitor — Window-Re-Block + frische Reflexions-Episode"
```

---

## Task 6: Geräte-Test-Checkliste

**Files:**
- Create: `docs/superpowers/device-test-checklist-reflexions-erlebnis.md`

- [ ] **Step 1: Checkliste anlegen**

```markdown
# Geräte-Test-Checkliste — Reflexions-Erlebnis (TP3)

Nur auf echtem iPhone prüfbar (Screen-Time-Frameworks haben im Simulator nur
Stubs). Autonomer Gate war ausschließlich der Simulator-Compile.

**Vorbereitung:** Blockier-Regel aus TP2 aktiv, Tageslimit zum Testen auf 5 Min,
Limit erreichen, damit das Schild steht.

## Schritte

- [ ] **1. Gebrandetes Schild:** Bei erreichtem Limit erscheint das ruhige
      "Kurz innehalten"-Schild mit Ring-Icon und einem Prompt — NICHT das
      System-"Restricted".
- [ ] **2. (LOAD-BEARING) `.defer`-Re-Render:** "Durchatmen" tippen → das Schild
      wechselt zu Screen 2 ("Atme dreimal tief durch"). Falls es stattdessen
      schließt/hängt: dokumentierter `.defer`-Wackler — vermerken.
- [ ] **3. Unlock:** Auf Screen 2 "Ich bin bereit" → App wird nutzbar (ggf. App
      erneut öffnen; nach `.close` landet man kurz auf Home).
- [ ] **4. (LOAD-BEARING) Re-Block nach Nutzung:** Nach ~5 Min echter Nutzung
      legt sich das Schild wieder über die App (Fenster-Schwelle; grobe
      Auflösung erwartbar). Pausieren/Weglegen sollte die 5 Min verlängern
      (Nutzungszeit, nicht Uhrzeit).
- [ ] **5. Exit:** Schild → "Beenden" → Home-Screen, App bleibt gesperrt.
- [ ] **6. Staleness-Guard:** "Durchatmen" (Screen 2) → App verlassen → >2 Min
      warten → App erneut öffnen. Erwartung: Schild beginnt wieder bei Screen 0,
      nicht out-of-context bei Screen 2.
- [ ] **7. Prompt-Rotation:** Über mehrere Schild-Episoden hinweg wechseln die
      Prompts (Zufallsauswahl).

## Ergebnis zurückmelden
Besonders 2 und 4 entscheiden, ob die gestufte Reibung und der Re-Block tragen.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/device-test-checklist-reflexions-erlebnis.md
git commit -m "docs(reflexion): Geräte-Test-Checkliste (.defer, Re-Block, Staleness)"
```

---

## Self-Review (vom Autor durchgeführt)

**Spec-Abdeckung:**
- C1 ShieldAction-Target → Task 2 (Skelett) + Task 3 (Logik). ✓
- C2 ReflectionStore (stage/prompt/log, effectiveStage, beginShieldEpisode, appendLog) → Task 1 Step 3. ✓
- C3 gestuftes gebrandetes Schild + Ring-Icon → Task 4. ✓
- C4 ShieldAction handle (stage 0→.defer, stage 1→grant, secondary→exit) → Task 3. ✓
- C5 DeviceActivityManager-Move + startEarnedWindow/stopEarnedWindow + Monitor-Erweiterung → Task 1 (Move/Window) + Task 5 (Monitor). ✓
- C6 Ring-Icon programmatisch (kein Asset-Catalog) → Task 4 `ShieldPalette.ringIcon()`. ✓
- D1 Schild-Löschen gibt alle Apps frei → Task 3 `grantWindow` (`shield.applications = nil`). ✓
- D2 Stage-Hygiene + Staleness-Guard → Task 1 (`effectiveStage`, `beginShieldEpisode`) + Task 3 (Reset bei grant/exit). ✓
- E Verifizierung → „Wichtig"-Abschnitt + Task 6. ✓
- Re-Block-Korrektheit (`intervalStart = jetzt`, sonst Sofort-Feuer) → Task 1 `startEarnedWindow`. ✓

**Platzhalter-Scan:** keine TBD/TODO; jeder Code-Schritt zeigt vollständigen Code. ✓

**Typ-Konsistenz:** `ReflectionStore.{effectiveStage,setStage,beginShieldEpisode,appendLog,currentPrompt,windowUsageMinutes}` einheitlich Task 1/3/4/5; `ReflectionOutcome.{extended,exited}` Task 1/3; `DeviceActivityManager.{startEarnedWindow,stopEarnedWindow,windowActivityName,activityName}` definiert Task 1, genutzt Task 3/5; `BlockRuleStore.{managedStore,selection,appGroupID}` aus TP2 unverändert genutzt. ✓
