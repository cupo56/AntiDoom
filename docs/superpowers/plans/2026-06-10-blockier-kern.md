# Blockier-Kern (Teilprojekt 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein gemeinsames Tageskontingent über ausgewählte Apps; beim Erreichen legt sich das Apple-Default-Schild über die Apps, das bis Mitternacht bestehen bleibt.

**Architecture:** Eine Regel (App-Tokens + Limit + aktiv) lebt in App-Group-`UserDefaults` (`BlockRuleStore`). Die App startet via `DeviceActivityCenter` ein `DeviceActivityEvent` mit Minuten-Schwelle über einen täglich wiederholenden `DeviceActivitySchedule`. Die `DeviceActivityMonitor`-Extension setzt beim Schwellwert das Schild über einen **benannten** `ManagedSettingsStore` und löscht es bei `intervalDidStart` (Tages-Reset). Die App-UI ist ein funktional-minimaler Ein-Regel-Screen mit Design-System-Tokens.

**Tech Stack:** Swift / SwiftUI, FamilyControls, DeviceActivity, ManagedSettings, App-Group-UserDefaults, `xcodeproj`-Ruby-Gem fürs Projektfile.

**Spec:** `docs/superpowers/specs/2026-06-10-blockier-kern-design.md`

---

## Wichtig: Verifizierung in diesem Projekt

Es gibt **kein Unit-Test-Target** (siehe `CLAUDE.md`). Der autonome Verifizierungs-Gate ist der **Simulator-Compile**:

```bash
./scripts/build-sim.sh
```

Erwartete Endzeile bei Erfolg: `** BUILD SUCCEEDED **`.

Die TDD-typischen „failing test"-Schritte sind hier **nicht anwendbar** — keine der Kernfunktionen (Schwelle feuert, Schild erscheint, Reset) ist im Simulator testbar. Jeder Task endet daher mit `build-sim` + Commit. Das tatsächliche Verhalten prüft der Nutzer auf dem Gerät (Task 6 liefert die Checkliste).

---

## File Structure

| Datei | Verantwortung | Neu/Ändern |
|---|---|---|
| `Shared/BlockRuleStore.swift` | Persistenz der Regel + geteilte Konstanten (`managedStoreName`) + benannter `ManagedSettingsStore` | **Neu** (in alle 3 Targets) |
| `scripts/pbxproj/03_add_blockrule.rb` | trägt die Shared-Datei in alle 3 Target-Compile-Phasen ein (idempotent) | **Neu** |
| `AntiDoom/DeviceActivityManager.swift` | DeviceActivity-Monitoring starten/stoppen | **Neu** (App-Target, sync) |
| `DeviceActivityMonitor/DeviceActivityMonitorExtension.swift` | Schwelle → Schild setzen; Tages-Reset | **Ändern** (Skelett füllen) |
| `AntiDoom/BlockRuleView.swift` | Konfigurations-UI (Picker, Limit, Aktivieren) | **Neu** (App-Target, sync) |
| `AntiDoom/ContentView.swift` | Authorization-Gate → zeigt `BlockRuleView`, wenn `.approved` | **Ändern** |
| `docs/superpowers/device-test-checklist-blockier-kern.md` | Geräte-Testschritte | **Neu** |

`AntiDoom/`, `DeviceActivityMonitor/` und `ShieldConfiguration/` sind synchronisierte Ordner — neue Dateien dort joinen ihr Target automatisch. **Nur** `Shared/` ist ein manueller Group und braucht das pbxproj-Skript.

---

## Task 1: `BlockRuleStore` — geteilte Persistenz + Konstanten

**Files:**
- Create: `Shared/BlockRuleStore.swift`
- Create: `scripts/pbxproj/03_add_blockrule.rb`

- [ ] **Step 1: Datei `Shared/BlockRuleStore.swift` anlegen**

```swift
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
```

- [ ] **Step 2: pbxproj-Skript `scripts/pbxproj/03_add_blockrule.rb` anlegen**

```ruby
#!/usr/bin/env ruby
# Trägt Shared/BlockRuleStore.swift in den Shared-Group ein und kompiliert es in
# alle drei Targets (App + beide Extensions). Idempotent.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
group = project.main_group.find_subpath('Shared', true)
group.set_path('Shared')

name = 'BlockRuleStore.swift'
ref = group.files.find { |f| f.display_name == name } || group.new_reference(name)

%w[AntiDoom DeviceActivityMonitor ShieldConfiguration].each do |target_name|
  target = project.targets.find { |t| t.name == target_name } or abort "#{target_name} not found"
  already = target.source_build_phase.files.any? { |bf| bf.file_ref == ref }
  target.add_file_references([ref]) unless already
end

project.save
puts "Added #{name} to all three targets."
```

- [ ] **Step 3: Skript ausführen**

Run: `ruby scripts/pbxproj/03_add_blockrule.rb`
Expected: `Added BlockRuleStore.swift to all three targets.`

- [ ] **Step 4: Verdrahtung prüfen — Datei in 3 Compile-Phasen**

Run: `grep -c "BlockRuleStore.swift in Sources" AntiDoom.xcodeproj/project.pbxproj`
Expected: `3`

- [ ] **Step 5: Compile-Gate**

Run: `./scripts/build-sim.sh`
Expected: endet mit `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Shared/BlockRuleStore.swift scripts/pbxproj/03_add_blockrule.rb AntiDoom.xcodeproj/project.pbxproj
git commit -m "feat(blockier-kern): BlockRuleStore — geteilte Regel-Persistenz + Konstanten"
```

---

## Task 2: `DeviceActivityManager` — Monitoring starten/stoppen

**Files:**
- Create: `AntiDoom/DeviceActivityManager.swift`

- [ ] **Step 1: Datei `AntiDoom/DeviceActivityManager.swift` anlegen**

```swift
//  DeviceActivityManager.swift
//  Kapselt das Starten/Stoppen der DeviceActivity-Überwachung für die eine
//  Blockier-Regel: ein gemeinsames Event mit Minuten-Schwelle über einen
//  täglich wiederholenden Zeitplan.

import Foundation
import DeviceActivity
import FamilyControls

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
```

> **Hinweis zum Re-Arm-Risiko (Spec C):** Falls der Geräte-Test zeigt, dass das Event über Tage **nicht** neu scharf stellt oder bei `includesPastActivity` sofort feuert, ist der Fallback: in der Extension bei `intervalDidStart` `start(...)` erneut aufrufen (stop+restart). Erst einbauen, wenn der Gerätetest es erfordert — nicht prophylaktisch.

- [ ] **Step 2: Compile-Gate**

Run: `./scripts/build-sim.sh`
Expected: endet mit `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/DeviceActivityManager.swift
git commit -m "feat(blockier-kern): DeviceActivityManager — Monitoring start/stop"
```

---

## Task 3: Monitor-Extension füllen — Schild setzen + Tages-Reset

**Files:**
- Modify: `DeviceActivityMonitor/DeviceActivityMonitorExtension.swift`

- [ ] **Step 1: Skelett durch echte Logik ersetzen**

Gesamten Dateiinhalt ersetzen durch:

```swift
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
```

- [ ] **Step 2: Compile-Gate**

Run: `./scripts/build-sim.sh`
Expected: endet mit `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add DeviceActivityMonitor/DeviceActivityMonitorExtension.swift
git commit -m "feat(blockier-kern): Monitor setzt Schild bei Schwelle, Reset bei Intervallstart"
```

---

## Task 4: `BlockRuleView` — Konfigurations-UI

**Files:**
- Create: `AntiDoom/BlockRuleView.swift`

- [ ] **Step 1: Datei `AntiDoom/BlockRuleView.swift` anlegen**

```swift
//  BlockRuleView.swift
//  Funktional-minimaler Ein-Regel-Screen: Apps wählen, gemeinsames Tageslimit
//  setzen, Regel aktivieren/deaktivieren. Baut auf dem Design-System auf.

import SwiftUI
import FamilyControls

struct BlockRuleView: View {
    @State private var selection = BlockRuleStore.selection
    @State private var limitMinutes = BlockRuleStore.limitMinutes
    @State private var isActive = BlockRuleStore.isActive
    @State private var pickerPresented = false
    @State private var errorMessage: String?

    private var appCount: Int { selection.applicationTokens.count }
    private var canActivate: Bool { appCount > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                header

                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionLabel("Apps")
                        Text(appCount == 0 ? "Noch keine App gewählt"
                                           : "\(appCount) App\(appCount == 1 ? "" : "s") gewählt")
                            .font(Theme.Fonts.body(16))
                            .foregroundStyle(Theme.Colors.ink)
                        Button("Apps auswählen") { pickerPresented = true }
                            .buttonStyle(.secondary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionLabel("Tageslimit")
                        Stepper(value: $limitMinutes, in: 5...120, step: 5) {
                            Text("\(limitMinutes) Min/Tag")
                                .font(Theme.Fonts.body(16))
                                .foregroundStyle(Theme.Colors.ink)
                        }
                        .onChange(of: limitMinutes) { _, newValue in
                            BlockRuleStore.limitMinutes = newValue
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                }

                actionButton
                statusText
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas)
        .familyActivityPicker(isPresented: $pickerPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in
            BlockRuleStore.selection = newValue
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text("Blockier-Regel")
                .font(Theme.Fonts.display(28))
                .foregroundStyle(Theme.Colors.ink)
            Text("Ein gemeinsames Tageslimit über deine gewählten Apps.")
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.l)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isActive {
            Button("Deaktivieren") { deactivate() }
                .buttonStyle(.secondary)
        } else {
            Button("Aktivieren") { activate() }
                .buttonStyle(.primary)
                .disabled(!canActivate)
        }
    }

    private var statusText: some View {
        Text(isActive ? "Aktiv — Limit wird überwacht ✓" : "Inaktiv")
            .font(Theme.Fonts.body(14, weight: .semibold))
            .foregroundStyle(isActive ? Theme.Colors.accent : Theme.Colors.inkMuted)
    }

    private func activate() {
        BlockRuleStore.selection = selection
        BlockRuleStore.limitMinutes = limitMinutes
        do {
            try DeviceActivityManager.start(selection: selection, limitMinutes: limitMinutes)
            BlockRuleStore.isActive = true
            isActive = true
            errorMessage = nil
        } catch {
            errorMessage = "Aktivierung fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func deactivate() {
        DeviceActivityManager.stop()
        BlockRuleStore.isActive = false
        isActive = false
        errorMessage = nil
    }
}

#Preview("Hell") {
    BlockRuleView().preferredColorScheme(.light)
}

#Preview("Dunkel") {
    BlockRuleView().preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Compile-Gate**

Run: `./scripts/build-sim.sh`
Expected: endet mit `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/BlockRuleView.swift
git commit -m "feat(blockier-kern): BlockRuleView — Picker, Limit-Stepper, Aktivieren/Deaktivieren"
```

---

## Task 5: `ContentView` — nach Authorization zur Regel-Ansicht

**Files:**
- Modify: `AntiDoom/ContentView.swift`

- [ ] **Step 1: `body` so ändern, dass bei erteilter Berechtigung `BlockRuleView` erscheint**

Ersetze den gesamten `var body: some View { ... }`-Block durch:

```swift
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
```

> Hinweis: `isApproved`, `statusText`, `requestAuthorization()`, die `@State`-Properties und die `#Preview`-Blöcke bleiben unverändert. Der `.onAppear`-Status-Refresh wandert mit in den `authorizationGate`.

- [ ] **Step 2: Compile-Gate**

Run: `./scripts/build-sim.sh`
Expected: endet mit `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/ContentView.swift
git commit -m "feat(blockier-kern): ContentView zeigt BlockRuleView nach Berechtigung"
```

---

## Task 6: Geräte-Test-Checkliste

**Files:**
- Create: `docs/superpowers/device-test-checklist-blockier-kern.md`

- [ ] **Step 1: Checkliste anlegen**

```markdown
# Geräte-Test-Checkliste — Blockier-Kern (TP2)

Diese Schritte sind **nur auf einem echten iPhone** prüfbar (die Screen-Time-
Frameworks haben im Simulator nur nicht-funktionale Stubs). Der autonome Gate war
ausschließlich der Simulator-Compile.

**Test-Pragmatik:** Limit zum Testen auf **5 Min** (Minimum) setzen — nicht 30
echte Minuten verbrennen. Die Feuer-Auflösung von DeviceActivity ist grob:
„feuert bei ~6–7 Min statt exakt 5" ist **erwartbar**, kein Fehler.

## Schritte

- [ ] **0. Vorbereitung:** Berechtigung ist erteilt (TP1); App zeigt den
      „Blockier-Regel"-Screen.
- [ ] **1. App-Auswahl persistiert:** „Apps auswählen" → eine Social-App wählen →
      Picker schließen. „X App gewählt" stimmt. App **neu starten** → Auswahl ist
      noch da (App-Group-UserDefaults).
- [ ] **2. Aktivieren:** Limit auf 5 Min, „Aktivieren". Status: „Aktiv ✓".
- [ ] **3. (LOAD-BEARING) Schwelle feuert → Schild:** Die gewählte App ~5–7 Min
      nutzen. Erwartung: Apple-Default-Schild legt sich über die App.
      - Feuert es **sofort** beim Aktivieren? → bekannter iOS-26-Bug
        (`includesPastActivity`); im Plan-Hinweis (Task 2) vermerkt.
      - Feuert es **gar nicht** nach deutlicher Überschreitung? → Extension wurde
        evtl. nicht gestartet; ggf. Telefon neu starten und erneut testen.
- [ ] **4. Deaktivieren löscht Schild sofort:** In der App „Deaktivieren". Das
      Schild über der App muss **sofort** verschwinden (beweist symmetrische
      `ManagedSettingsStore`-Benennung).
- [ ] **5. (LOAD-BEARING, MEHR-TAGES-TEST) Tages-Reset & Re-Arm:** Wieder
      aktivieren, Limit erreichen (Schild steht). Am **Folgetag** prüfen:
      - Ist das Schild über Nacht **verschwunden** (Reset via `intervalDidStart`)?
      - Feuert die Schwelle nach erneuter Nutzung am Folgetag **wieder** (Re-Arm)?
      - Falls **nein** bei einem der beiden Punkte: Re-Arm greift nicht → Fallback
        aus Spec C einbauen (stop+restart bei `intervalDidStart`).

## Ergebnis zurückmelden
Welche Punkte grün/rot — besonders 3 und 5 entscheiden, ob der native Loop trägt
oder der stop/restart-Fallback nötig ist.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/device-test-checklist-blockier-kern.md
git commit -m "docs(blockier-kern): Geräte-Test-Checkliste (Schwelle, Reset, Re-Arm)"
```

---

## Self-Review (vom Autor durchgeführt)

**Spec-Abdeckung:**
- Entscheidung „Nutzungslimit" → Task 2 (`DeviceActivityEvent` + Schwelle). ✓
- „Ein gemeinsames Kontingent" → ein Event über `applicationTokens`. ✓
- „Erst am nächsten Tag" + Deaktivieren löscht → Task 3 (`intervalDidStart` Reset) + Task 2 (`stop()` löscht). ✓
- „App-Group UserDefaults" → Task 1 (`BlockRuleStore`). ✓
- Spec B1 geteilte Konstante `managedStoreName` → Task 1. ✓
- Spec B2 UI (Picker, Stepper, Aktivieren, Status, nur Anzahl statt Namen) → Task 4. ✓
- Spec B3 `DeviceActivityManager` → Task 2. ✓
- Spec B4 Monitor → Task 3. ✓
- Spec B5 ShieldConfiguration bleibt Default → **bewusst kein Task** (unverändert). ✓
- Spec C Re-Arm-Risiko/Fallback → Plan-Hinweis Task 2 + Checkliste Task 6 #3/#5. ✓
- Spec D ehrliche Verifizierung → „Wichtig"-Abschnitt + Task 6. ✓
- Spec F Abgrenzung (nur App-Tokens) → Task 1/2 nutzen nur `applicationTokens`. ✓

**Platzhalter-Scan:** keine TBD/TODO/„appropriate error handling" — jeder Code-Schritt zeigt vollständigen Code. ✓

**Typ-Konsistenz:** `BlockRuleStore.selection/limitMinutes/isActive/managedStore/managedStoreName` einheitlich über Tasks 1–5; `DeviceActivityManager.start(selection:limitMinutes:)` / `stop()` in Task 2 definiert und in Task 4 identisch aufgerufen; `activityName`/`eventName` nur in Task 2. ✓
