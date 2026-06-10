# Design: Teilprojekt 2 — Blockier-Kern (MVP)

**Datum:** 2026-06-10
**Status:** Genehmigt
**App:** AntiDoom — psychologische Achtsamkeits-Schranke gegen Doom-Scrolling (siehe `README.md`)

## Kontext & Ziel

Teilprojekt 1 hat das technische Fundament gelegt (drei Targets, App Group,
geteilter Store, FamilyControls-Authorization, Design-System). Dieses Dokument
spezifiziert **Teilprojekt 2: den Blockier-Kern** — das erste sichtbare Feature.

Der Kern ist ein **gemeinsames Tageskontingent**: Der Nutzer wählt Apps aus und
setzt ein gemeinsames Zeitlimit (z.B. 30 Min/Tag für alle ausgewählten Apps
zusammen). Wird das Limit erreicht, legt sich ein Schild über die Apps, das bis
zum nächsten Tag (Mitternacht) bestehen bleibt.

Die **Reflexions-/Verlängerungs-Mechanik** (durch eine Achtsamkeitsübung Zeit
zurückgewinnen) und das **eigene Schild-Design** sind bewusst **nicht** Teil
dieses Teilprojekts — sie kommen in Teilprojekt 3 (Reflexions-Erlebnis). TP2
nutzt das Apple-Default-Schild.

### Entscheidungen (vom Nutzer bestätigt)

| Frage | Entscheidung |
|---|---|
| Auslöser der Sperre | **Nutzungslimit (Zeitkontingent)** — `DeviceActivityEvent` mit Zeitschwelle über täglichen Zeitplan |
| Granularität | **Ein gemeinsames Kontingent** für alle ausgewählten Apps (ein einziges Event) |
| Entsperren | **Erst am nächsten Tag** (täglicher Reset). Regel deaktivieren löscht das Schild sofort (zugleich Test-/Notausgang) |
| Speicherung | **App-Group `UserDefaults`** (`FamilyActivitySelection` ist Codable) — die kurzlebige Extension liest leichtgewichtig; `FoundationProbe`/SwiftData bleibt unangetastet |

## A. Datenfluss (Überblick)

```
App (Konfiguration)                         System / Extension
───────────────────                         ──────────────────
FamilyActivityPicker → Tokens
Limit (Minuten)
        │ "Aktivieren"
        ▼
BlockRuleStore.save(selection, limit, active=true)   (App-Group UserDefaults)
DeviceActivityManager.start()
  → DeviceActivityCenter.startMonitoring(
        schedule: täglich 00:00–23:59 repeats,
        events: [limitReached: Event(apps: tokens, threshold: limit)])
                                            │
                                            │  Nutzung läuft …
                                            ▼
                              eventDidReachThreshold (Monitor-Extension)
                                → ManagedSettingsStore(named: "antidoom")
                                     .shield.applications = tokens
                                            │  Schild steht
                                            ▼
                              intervalDidStart (neuer Tag, 00:00)
                                → store.shield.applications = nil   ← Tages-Reset

App (Deaktivieren)
  → DeviceActivityCenter.stopMonitoring([name])
  → ManagedSettingsStore(named: "antidoom").clearAllSettings()      ← Schild weg
  → BlockRuleStore: active = false
```

## B. Komponenten

### B1. `Shared/BlockRuleStore.swift` (App + Monitor-Extension)

Ein schlanker Helfer, per Target-Membership in **App und `DeviceActivityMonitor`**
kompiliert (wie `SharedStore`). Liest/schreibt App-Group-`UserDefaults`:

- `selection: FamilyActivitySelection` — als `Data` (JSON, `Codable`)
- `limitMinutes: Int`
- `isActive: Bool`

Hier wohnen auch die **geteilten Konstanten** neben `SharedStore.appGroupID`:

- `appGroupID = "group.antidoom.AntiDoom"` (bereits vorhanden)
- `managedStoreName = "antidoom"` — der Name des `ManagedSettingsStore`.
  **Load-bearing:** Die Extension (setzt das Schild) und die App (löscht das
  Schild beim Deaktivieren) MÜSSEN denselben benannten Store referenzieren —
  ein Default-vs.-benannt-Mismatch führt dazu, dass „Deaktivieren" das Schild
  still nicht entfernt.

Nur **App-Tokens** werden gespeichert/verwendet (`selection.applicationTokens`).
Kategorien und Web-Domains aus dem Picker werden im MVP **ignoriert**, damit das
Event-Set und das Schild-Set deckungsgleich sind.

### B2. App-UI — Blockier-Regel-Screen

Ein funktional-minimaler **Ein-Regel-Screen** (kein Dashboard — das ist TP4),
durchgehend mit Design-System-Tokens (`Theme.*`, `Card`, Button-Styles) gebaut.
Sichtbar erst, wenn die Authorization `.approved` ist (sonst der bestehende
Authorization-Screen aus TP1).

Elemente:
- **„Apps auswählen"** → `.familyActivityPicker(isPresented:selection:)` →
  Auswahl wird in `@State` gehalten und beim Aktivieren persistiert.
- **Limit-Stepper** (Minuten, Bereich z.B. 5–120, Schrittweite 5).
- **„Aktivieren"/„Deaktivieren"** (Toggle oder Primär-/Sekundär-Button):
  - Aktivieren: `BlockRuleStore.save(active: true)` + `DeviceActivityManager.start()`.
  - Deaktivieren: `DeviceActivityManager.stop()` (stopMonitoring + Schild löschen)
    + `BlockRuleStore.active = false`.
- **Status-Anzeige:** Anzahl gewählter Apps, aktuelles Limit, aktiv/inaktiv.

Hinweis Datenschutz: `applicationTokens` sind opak — es gibt keine lesbaren
App-Namen. Die UI zeigt daher die **Anzahl** gewählter Apps, keine Klarnamen.
(Apples `Label(token)` kann Icons rendern; im MVP optional, nicht erforderlich.)

### B3. `DeviceActivityManager` (App-Target)

Kapselt die DeviceActivity-Verdrahtung:
- `DeviceActivityName` z.B. `"antidoom.daily"`, `DeviceActivityEvent.Name` z.B.
  `"antidoom.limitReached"`.
- `DeviceActivityEvent(applications: tokens, threshold: DateComponents(minute: limitMinutes))`.
- `DeviceActivitySchedule(intervalStart: 00:00, intervalEnd: 23:59, repeats: true)`.
- `start()`: `DeviceActivityCenter().startMonitoring(name, during: schedule, events: [eventName: event])`.
- `stop()`: `center.stopMonitoring([name])` + `ManagedSettingsStore(named: managedStoreName).clearAllSettings()`.

### B4. `DeviceActivityMonitorExtension` (Skelett füllen)

- `eventDidReachThreshold(_:activity:)` → liest `selection.applicationTokens` aus
  `BlockRuleStore` → `store.shield.applications = tokens` (benannter Store).
- `intervalDidStart(for:)` → `store.shield.applications = nil` (**Tages-Reset**).
- `intervalDidEnd(for:)` → optionales Aufräumen (kein zwingender Effekt).

### B5. `ShieldConfigurationExtension`

Bleibt im MVP das **Apple-Default-Schild** (`ShieldConfiguration()`). Das eigene
Reflexions-Schild gehört zu TP3. (Eine minimale Kosmetik wie ein Titel ist
optional; bewusst zurückgestellt, um den TP2/TP3-Schnitt sauber zu halten.)

## C. Explizite Risiko-Annahme (load-bearing)

Der gesamte Tages-Loop hängt an zwei gekoppelten Annahmen über die
DeviceActivity-Plattform:

1. `eventDidReachThreshold` **stellt sich an jeder neuen Tages-Intervallgrenze
   neu scharf** (re-arm), feuert also nicht nur am ersten Tag.
2. `intervalDidStart` **feuert um Mitternacht**, damit das Schild gelöscht
   (zurückgesetzt) werden kann.

Auf iOS 26.x sind hierzu **dokumentierte Regressionen** bekannt
(Apple Developer Forums, Threads 811305 / 808470 / 737741): Events feuern
mitunter **sofort** (besonders bei `includesPastActivity = false`), **gar nicht**
oder verzögert, und die Monitor-Extension wird gelegentlich nicht gestartet.

**Maßnahmen:**
- Diese Annahme ist **kein stiller Default**, sondern wird zum **Geräte-Test #1**
  (siehe Abschnitt D) und braucht einen **Mehr-Tages-Test**.
- `includesPastActivity` wird bewusst gesetzt und als Risiko benannt (Sofort-Feuer-Bug);
  der Default-Wert wird im Plan festgelegt und auf dem Gerät verifiziert.
- **Fallback**, falls das Event über Tage nicht neu scharf stellt: Monitoring an
  der Intervallgrenze (`intervalDidEnd`/`intervalDidStart`) per `stopMonitoring`
  + `startMonitoring` **neu aufsetzen**, um das Event zwangsweise zurückzusetzen.
  Dieser Fallback wird nur eingebaut, wenn der Geräte-Test zeigt, dass das
  native Re-Arming nicht greift — nicht prophylaktisch.

## D. Verifizierung — ehrliche Aufteilung

**Was Claude autonom prüft (der verlässliche Hebel):**
- Das Projekt **kompiliert** sauber (`./scripts/build-sim.sh`, App + beide
  Extensions, ohne Signing).
- **Keine** Kernfunktion ist im Simulator testbar — die Screen-Time-Frameworks
  haben dort nur nicht-funktionale Stubs.

**Was nur der Nutzer auf dem echten iPhone prüfen kann (Geräte-Checkliste):**
1. **(load-bearing, Mehr-Tages-Test)** Schwelle feuert → Schild erscheint; und
   am **Folgetag** feuert sie **erneut** (Re-Arm) → Reset um Mitternacht greift.
2. Schild erscheint über genau den ausgewählten Apps.
3. „Deaktivieren" entfernt das Schild **sofort** (beweist symmetrische
   Store-Benennung).
4. Picker-Auswahl überlebt App-Neustart (Persistenz in App-Group-UserDefaults).

**Test-Pragmatik:** Mit einer **kurzen Schwelle** testen (z.B. 1 Min), nicht
30 echte Minuten verbrennen. **Warnung:** Die Feuer-Auflösung von DeviceActivity
ist grob — „feuert bei ~2 Min, obwohl 1 gesetzt" ist **erwartbar**, kein Fehler.

Es wird **nicht** behauptet „der Blockier-Loop funktioniert" — das bestätigen
ausschließlich die Geräte-Tests des Nutzers. Der autonome Gate ist der
Simulator-Compile.

## E. Roadmap (Kontext — spätere Teilprojekte, NICHT Teil dieses Specs)

1. **Fundament & Berechtigung** — fertig (TP1)
2. **Blockier-Kern (MVP)** ← dieses Dokument
3. **Reflexions-Erlebnis:** eigene Shield-UI mit Reflexionsfragen +
   Verlängerungs-Mechanik (inkl. `ShieldAction`-Extension)
4. **Dashboard & Persistenz:** Reflexions-Sessions, Emotions-Tracking, Statistiken
5. **Gamification:** progressive Timer, Level-System, Streaks

## F. Abgrenzung (explizit NICHT in diesem Teilprojekt)

- Keine Pro-App-Limits (nur ein gemeinsames Kontingent)
- Keine Reflexions-/Verlängerungs-Mechanik, keine `ShieldAction`-Extension
- Kein eigenes Schild-Design (Apple-Default-Schild)
- Keine Kategorie-/Web-Domain-Sperren (nur App-Tokens)
- Kein Dashboard, keine Statistiken, keine Gamification
- Keine SwiftData-Domänenmodelle (`UsageRule` etc. kommen später) — TP2 nutzt
  ausschließlich App-Group-`UserDefaults` für die eine Regel
