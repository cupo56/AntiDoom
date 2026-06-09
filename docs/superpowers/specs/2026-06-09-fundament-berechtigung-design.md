# Design: Teilprojekt 1 — Fundament & Berechtigung

**Datum:** 2026-06-09
**Status:** Genehmigt
**App:** AntiDoom — psychologische Achtsamkeits-Schranke gegen Doom-Scrolling (siehe `README.md`)

## Kontext & Ziel

AntiDoom blockiert Social-Media-Apps über Apples Screen-Time-Frameworks und
ersetzt die blockierte App durch Reflexions-Übungen. Das Gesamtprojekt ist in
Teilprojekte zerlegt (siehe „Roadmap" unten). Dieses Dokument spezifiziert
**nur Teilprojekt 1: das technische Fundament** — ohne sichtbares Blockier-Feature,
aber mit der vollständigen technischen Basis, auf der alle weiteren Teilprojekte aufbauen.

### Voraussetzungen (vom Nutzer bestätigt)
- Echtes iPhone zum Testen vorhanden
- Kostenpflichtiger Apple Developer Account; Family-Controls-Entitlement wird
  für Entwicklung auf dem eigenen Gerät automatisch vergeben (für App-Store-
  Veröffentlichung später separat bei Apple zu beantragen)
- Target-Anlage erfolgt durch **direktes Editieren von `project.pbxproj`**
  (Nutzer-Entscheidung), mit Fallback siehe Abschnitt F

## A. Target-Struktur

Drei Targets im Xcode-Projekt:

| Target | Typ | Rolle (jetzt) |
|---|---|---|
| `AntiDoom` | App (existiert) | Haupt-App + Status-/Onboarding-Screen |
| `DeviceActivityMonitor` | App Extension (neu) | `DeviceActivityMonitor`-Subklasse, Skelett |
| `ShieldConfiguration` | App Extension (neu) | `ShieldConfigurationDataSource`-Subklasse, Skelett |

- Beide Extensions kommen als **funktionsfähige Skelette**: sie kompilieren,
  sind korrekt verdrahtet (Info.plist `NSExtensionPointIdentifier`, Signing,
  Embed-in-App), enthalten aber noch keine echte Logik.
- Extension-Point-Identifier:
  - DeviceActivityMonitor: `com.apple.deviceactivity.monitor-extension`
  - ShieldConfiguration: `com.apple.ManagedSettingsUI.shield-configuration-service`
- Bundle-IDs: `antidoom.AntiDoom.DeviceActivityMonitor`,
  `antidoom.AntiDoom.ShieldConfiguration`
- Die `ShieldAction`-Extension (Reaktion auf Schild-Button-Taps) ist **nicht**
  Teil dieses Teilprojekts — sie kommt mit dem Reflexions-Erlebnis (Teilprojekt 3).

## B. App Group & geteilter Datenspeicher

- App Group: **`group.antidoom.AntiDoom`**, aktiviert auf allen drei Targets.
- Ein zentraler `SharedStore`-Helper (in einer Datei, die per Target-Membership
  von App **und** Extensions genutzt wird) baut den `ModelContainer` mit:
  ```swift
  ModelConfiguration(groupContainer: .identifier("group.antidoom.AntiDoom"))
  ```
  Damit App und Extensions später dieselbe SwiftData-DB sehen.
- Das Template-Modell `Item` wird durch **ein minimales, reales Foundation-Modell**
  ersetzt, dessen einziger Zweck ist, den geteilten Store zu beweisen. Die echten
  Domänen-Modelle (Reflexions-Sessions, Nutzungsregeln, Statistiken) werden
  **nicht** hier definiert, sondern jeweils in ihrem Teilprojekt (YAGNI).
- **Forward-Hinweis fürs spätere Datenmodell:** `FamilyActivityPicker` liefert nur
  opake `ApplicationToken`s zurück — keine lesbaren App-Namen oder Bundle-IDs
  (Datenschutz). Spätere Modelle speichern **Tokens**, keine Klarnamen. Das
  Fundament-Modell trifft daher keine Annahme über lesbare App-Identifikatoren.

## C. FamilyControls-Authorization

- Authorization-Schicht: `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
- Die Template-`ContentView` (Item-Liste) wird ersetzt durch einen **minimalen
  Status-Screen**: zeigt den aktuellen Authorization-Status (`.notDetermined` /
  `.approved` / `.denied`) und einen „Berechtigung anfragen"-Button. Keine
  aufwändige UI — die kommt in späteren Teilprojekten.

## D. Entitlements (pro Target)

Jedes der drei Targets erhält eine `.entitlements`-Datei mit:
- `com.apple.developer.family-controls = true`
- `com.apple.security.application-groups = [group.antidoom.AntiDoom]`

## E. Verifizierung — ehrliche Aufteilung

**Was Claude automatisch prüft (autonomer Hebel):**
- Projekt **kompiliert** sauber im **Simulator-Build** (`xcodebuild build`,
  Destination iOS-Simulator). Die Screen-Time-Frameworks haben Simulator-Stubs,
  die bauen, aber nicht funktional sind.
- Projektstruktur intakt: beide Extensions als Targets vorhanden, Entitlements
  gesetzt, Embed-Phase bindet Extensions in die App ein.

**Was nur der Nutzer auf dem echten iPhone prüfen kann (und zurückmeldet):**
- Der FamilyControls-Berechtigungsdialog erscheint und liefert `.approved`.
- Die App installiert mit beiden eingebetteten, korrekt signierten Extensions.
- Der SwiftData-Container zeigt auf den App-Group-Pfad.

Es wird **nicht** behauptet „es funktioniert" — das bestätigen ausschließlich die
Geräte-Tests des Nutzers. Offen/Risiko: ob in der Entwicklungsumgebung überhaupt
ein signierter Geräte-Build möglich ist; der verlässliche autonome Hebel ist der
Simulator-Compile. Eine vollständige Cross-Prozess-Verifizierung (Extension
schreibt → App liest) ist erst im nächsten Teilprojekt möglich, wenn eine
Blockierung tatsächlich konfiguriert ist und die Extensions laufen.

## F. Risiko-Absicherung beim pbxproj-Editieren

Die Projektdatei nutzt das neue Format (`objectVersion = 77`,
`PBXFileSystemSynchronizedRootGroup`). Targets von Hand hinzuzufügen
(Native Target + Config-Lists + Build-Phasen + Product-Ref + Embed-Copy-Phase)
ist fummelig. Maßnahmen:
- **Ein Target nach dem anderen** anlegen, nach jedem ein Simulator-Build —
  ein Fehler bleibt damit lokal und ist diagnostizierbar.
- **Tripwire:** Bricht die Projektdatei und ist nicht in 1–2 Versuchen zu retten,
  Fallback auf „Nutzer legt die Target-Skelette in Xcode an
  (`File > New > Target`), Claude füllt Code/Entitlements/App-Group". Kein
  endloses Loopen auf pbxproj-Chirurgie.

## Roadmap (Kontext — spätere Teilprojekte, NICHT Teil dieses Specs)

1. **Fundament & Berechtigung** ← dieses Dokument
2. **Blockier-Kern (MVP):** App über `FamilyActivityPicker` wählen, Limit/Zeitplan
   via DeviceActivity, echtes Schild auf blockierter App
3. **Reflexions-Erlebnis:** eigene Shield-UI mit Reflexionsfragen +
   Verlängerungs-Mechanik (inkl. `ShieldAction`-Extension)
4. **Dashboard & Persistenz:** Reflexions-Sessions, Emotions-Tracking, Statistiken
5. **Gamification:** progressive Timer, Level-System, Streaks

## Abgrenzung (explizit NICHT in diesem Teilprojekt)

- Keine echte Blockier-Logik, kein `FamilyActivityPicker`, kein DeviceActivity-Schedule
- Kein eigenes Schild-Design, keine Reflexionsfragen
- Keine Domänen-Datenmodelle über das minimale Foundation-Modell hinaus
- Kein Dashboard, keine Gamification
