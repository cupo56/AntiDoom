# Design: Teilprojekt 3 — Reflexions-Erlebnis (MVP)

**Datum:** 2026-06-11
**Status:** Genehmigt
**App:** AntiDoom — psychologische Achtsamkeits-Schranke gegen Doom-Scrolling (siehe `README.md`)

## Kontext & Ziel

Teilprojekt 2 hat den Blockier-Kern geliefert (gemeinsames Tageskontingent →
iOS-System-Schild „Restricted"). Dieses Dokument spezifiziert **Teilprojekt 3:
das Reflexions-Erlebnis** — der „Türsteher"-Moment, der AntiDoom von einem
nüchternen Blocker unterscheidet.

Statt des System-„Restricted" erscheint ein ruhig gestaltetes, **gestuftes**
Schild im „Ruhig & Minimal"-Look. Wer bewusst durch zwei Screens geht, gewinnt
**5 Minuten Nutzungszeit** zurück; wer „Beenden" wählt, geht raus. Jede
Entscheidung wird protokolliert (Grundlage für das Dashboard in TP4).

### Plattform-Grenzen (verifiziert, formen das Konzept)

Diese drei harten Grenzen wurden vor dem Design recherchiert und sind nicht
verhandelbar:

1. **Das Schild ist ein festes Template, kein SwiftUI-Canvas.** Stylebar sind nur
   Hintergrund (Farbe/Blur), **ein Icon-Bild** (`UIImage`), Titel, Untertitel und
   **zwei Buttons** (Text + Farbe). Keine Animation, keine interaktive Übung,
   **keine Texteingabe** im Schild.
2. **Ein Schild-Button kann die App AntiDoom NICHT öffnen** (keine offizielle API;
   der „One-Sec"-Deeplink-Trick ist inoffiziell/unzuverlässig). Die Reflexion
   passiert daher **vollständig im Schild**.
3. **Was ein Button KANN:** Code in einer `ShieldAction`-Extension auslösen, die
   die Sperre aufhebt/neu setzt und DeviceActivity-Monitoring startet.

### Verifizierte Mechanismen (Tore vor dem Design geschlossen)

- **`.defer` rendert das Schild neu:** `ShieldActionResponse.defer` löst sofort
  einen erneuten Aufruf von `configuration(shielding:)` aus → so funktioniert die
  gestufte Reibung (Screen 0 → Screen 1).
- **Die ShieldAction-Extension kann `DeviceActivityCenter().startMonitoring`
  aufrufen,** und die geplante Überwachung überlebt das Beenden der Extension —
  sie ist der eine wache Prozess im Moment des Button-Drucks.

## A. Entscheidungen (vom Nutzer bestätigt)

| Frage | Entscheidung |
|---|---|
| Reflexions-Reibung | **Gestuft** — zwei Schild-Screens via `.defer`-Re-Render |
| Zurückgewonnenes Fenster | **5 Minuten Nutzungszeit** (nicht Wall-Clock) |
| Re-Block-Mechanismus | **`DeviceActivityEvent` mit 5-Min-Nutzungs-Schwelle** — der in TP2 auf Gerät bewiesene Mechanismus (kein riskanter Kurz-Schedule) |
| Protokollierung | **Ab TP3**, schlank in App-Group-Speicher (wie TP2, kein SwiftData) |
| Prompt-Ton | **Beruhigend-erdend** (z.B. „Du musst gerade nichts. Atme.") |
| Schild-Icon | **Statisches Ring-Motiv** (Brand), programmatisch gerendert (kein Asset-Catalog) |

## B. Datenfluss

```
Tageslimit erreicht (TP2)
  → Monitor.eventDidReachThreshold:
        Schild setzen + frischen Prompt wählen + Stage=0      (ReflectionStore)

Nutzer öffnet App → Schild Screen 0 (Prompt + "Durchatmen"/"Beenden")
        │
        │  "Durchatmen"
        ▼
  ShieldAction.primaryButtonPressed (Stage 0):
        Stage=1, stageSetAt=now  →  .defer
        │
        ▼  iOS rendert neu → Schild Screen 1 ("Atme dreimal…", "Ich bin bereit"/"Beenden")
        │
        │  "Ich bin bereit"
        ▼
  ShieldAction.primaryButtonPressed (Stage 1):
        Schild löschen (alle Apps frei)
        DeviceActivityManager.startEarnedWindow()   → antidoom.window, 5-Min-Nutzungs-Event
        Log(outcome: .extended)
        Stage=0  →  .close
        │
        ▼  Nutzer scrollt … 5 Min Nutzung …
        ▼
  Monitor.eventDidReachThreshold (antidoom.window):
        Schild neu setzen + frischen Prompt + Stage=0
        antidoom.window stoppen

"Beenden" (jede Stufe):
  ShieldAction.secondaryButtonPressed:
        Log(outcome: .exited), Stage=0  →  .close
```

## C. Komponenten

### C1. Neuer Target `ShieldAction`

- App-Extension, Extension-Point `com.apple.ManagedSettings.shield-action-service`.
- Angelegt über `scripts/pbxproj/add_extension.rb` (idempotent, bettet `.appex` in
  die App ein). **`PRODUCT_NAME = $(TARGET_NAME)`** setzen (Gotcha aus CLAUDE.md,
  sonst kollidiert der Produkt-Wrapper).
- Entitlements (wie die anderen Targets): `com.apple.developer.family-controls` +
  App-Group `group.com.cupo.antidoom`.
- Bundle-ID-Schema analog: `com.cupo.antidoom.ShieldAction`.
- Klasse `ShieldActionExtension: ShieldActionDelegate`, überschreibt
  `handle(action:for:completionHandler:)`.
- `ReflectionStore`-Datei wird per Skript auch in dieses Target kompiliert.

### C2. `Shared/ReflectionStore.swift` (App + ShieldAction + ShieldConfiguration + Monitor)

Schlanker Helfer auf App-Group-`UserDefaults` (wie `BlockRuleStore`). Inhalt:
- `stage: Int` — 0 = Prompt-Screen, 1 = Innehalten-Screen.
- `stageSetAt: Date?` — Zeitstempel für den Staleness-Guard.
- `currentPromptIndex: Int` — beim Setzen des Schilds gewählt.
- `static let prompts: [String]` — kuratierte, beruhigend-erdende Liste, initial:
  - „Du musst gerade nichts. Atme."
  - „Dieser Moment gehört dir, nicht dem Feed."
  - „Spür kurz deinen Atem, bevor du weitergehst."
  - „Es ist okay, einfach hier zu sein."
  - „Nichts da drin braucht dich gerade dringend."
- `static let windowUsageMinutes = 5`.
- `effectiveStage: Int` — gibt `0` zurück, wenn `stage > 0` und `stageSetAt`
  älter als **2 Minuten** ist (Staleness-Guard), sonst `stage`.
- `func beginShieldEpisode()` — wählt frischen `currentPromptIndex`, setzt
  `stage = 0`. Aufgerufen, wenn das Schild (neu) gesetzt wird.
- `func setStage(_:)` — schreibt `stage` + `stageSetAt`.
- `func appendLog(outcome:)` — hängt `{promptIndex, outcome, timestamp}` an ein
  JSON-Array in App-Group-`UserDefaults` an. `outcome` ∈ `{extended, exited}`.

### C3. `ShieldConfigurationExtension` (bestehender Target, Skelett füllen)

Liest `effectiveStage` + `currentPromptIndex` und gibt ein gebrandetes
`ShieldConfiguration` zurück:
- **Gemeinsam:** `backgroundColor` = canvas, `backgroundBlurStyle` dezent, `icon`
  = statisches **Ring-Motiv** (siehe C6), Titel/Buttons in Design-System-Farben
  (sage Primär-Button, gedämpfter Sekundär).
- **Stage 0:** Titel „Kurz innehalten", Untertitel = `prompts[currentPromptIndex]`,
  Primär „Durchatmen", Sekundär „Beenden".
- **Stage 1:** Titel „Atme dreimal tief durch", Untertitel „Langsam ein … und
  wieder aus. Wenn du bereit bist, geht es weiter.", Primär „Ich bin bereit",
  Sekundär „Beenden".
- Alle vier `configuration(shielding:)`-Überladungen liefern dieselbe Config
  (gemeinsames Kontingent). **Keine Seiteneffekte** im Data-Source — Prompt-Wahl
  und Stage-Reset passieren im Monitor, nicht hier.

### C4. `ShieldActionExtension` (neuer Target)

`handle(action:for:completionHandler:)`:
- **`.primaryButtonPressed`:**
  - `effectiveStage == 0` → `setStage(1)`, `completion(.defer)`.
  - `effectiveStage == 1` → `BlockRuleStore.managedStore.shield.applications = nil`;
    `DeviceActivityManager.startEarnedWindow(selection:)`; `appendLog(.extended)`;
    `setStage(0)`; `completion(.close)`.
- **`.secondaryButtonPressed`:** `appendLog(.exited)`; `setStage(0)`;
  `completion(.close)`.
- Die Tokens fürs Fenster kommen aus `BlockRuleStore.selection.applicationTokens`.

> **UX-Detail (Geräte-Test):** Nach dem Gewähren via `.close` landet der Nutzer
> auf dem Home-Screen; beim erneuten Öffnen ist die App entsperrt. Ob ein direktes
> Dismiss (statt `.close`) angenehmer ist, wird auf dem Gerät geprüft — `.close`
> ist der sichere Default.

### C5. `DeviceActivityManager` (nach `Shared/` verschieben + erweitern) + Monitor (erweitern)

- **Verschiebung:** `DeviceActivityManager` liegt aktuell im App-Target
  (`AntiDoom/DeviceActivityManager.swift`), wird jetzt aber auch von der
  **ShieldAction**-Extension (`startEarnedWindow`) und der **Monitor**-Extension
  (`stopEarnedWindow`) aufgerufen. Er wandert daher nach `Shared/` und wird per
  pbxproj-Skript in App + ShieldAction + Monitor kompiliert (App-Membership-Move,
  nicht nur Add).
- **`DeviceActivityManager.startEarnedWindow(selection:)`:** startet die Activity
  `antidoom.window` mit einem `DeviceActivityEvent` (applications = Tokens,
  threshold = 5 Min, `includesPastActivity = false`) über einen Zeitplan bis
  Tagesende. Vorher `stopMonitoring([windowActivityName])` (sauberer Neustart).
- **`DeviceActivityManager.stopEarnedWindow()`:** `stopMonitoring([windowActivityName])`.
- **Monitor-Extension** bekommt zusätzlich:
  - `eventDidReachThreshold` für `antidoom.window` → Schild neu setzen
    (`store.shield.applications = tokens`), `ReflectionStore.beginShieldEpisode()`,
    `DeviceActivityManager.stopEarnedWindow()`.
  - Das bestehende Tages-`eventDidReachThreshold` ruft jetzt zusätzlich
    `ReflectionStore.beginShieldEpisode()` (frischer Prompt + Stage=0).

### C6. Ring-Motiv-Icon (kein Asset-Catalog)

Das Design-System nutzt bewusst keinen Asset-Catalog. Das Schild-Icon wird daher
**programmatisch** als `UIImage` gerendert (`UIGraphicsImageRenderer`): zwei
konzentrische, in Sage gestrichelte/gestrichene Kreise (das „BreathingRing"-Motiv
als Standbild). Helfer liegt in der ShieldConfiguration-Extension (oder Shared),
nutzt dieselben Sage-Werte wie `Theme`.

## D. Zwei bewusst gesetzte Festlegungen

1. **Schild-Löschen gibt ALLE Apps des gemeinsamen Kontingents frei** (nicht nur
   die gerade reflektierte App). Konsistent mit dem Ein-Kontingent-Modell aus TP2.
   Bewusste Entscheidung, kein Versehen.
2. **Stage-Hygiene:** `stage` wird auf 0 zurückgesetzt bei (a) Gewähren, (b)
   Beenden, (c) jedem (Neu-)Setzen des Schilds (`beginShieldEpisode`). Zusätzlich
   der **Staleness-Guard** (`effectiveStage`): ein im Hintergrund gelandetes
   Halb-Schild (stage 1, älter als 2 Min) wird als Stage 0 behandelt und taucht
   nicht out-of-context auf Screen 2 wieder auf.

## E. Verifizierung — ehrliche Aufteilung

**Autonom (Claude):** Projekt **kompiliert** inkl. des neuen `ShieldAction`-Targets
(`./scripts/build-sim.sh`). Keine Verhaltens-Aussage — Schild/Reflexion/Re-Block
laufen nicht im Simulator.

**Geräte-Test (nur Nutzer, load-bearing):**
1. Bei erreichtem Limit erscheint das **gebrandete Schild** (nicht „Restricted").
2. „Durchatmen" rendert tatsächlich **Screen 2** (`.defer`-Re-Render; dokumentierte
   Wackler — daher explizit testen).
3. „Ich bin bereit" gibt den Zugang frei; App ist nutzbar.
4. Nach **~5 Min Nutzung** feuert der Re-Block (Fenster-Schwelle, grobe Auflösung
   erwartbar).
5. „Beenden" → Home-Screen, Log-Eintrag `exited`.
6. Kein Stuck-Mid-Stage: App während Screen 2 verlassen, später erneut öffnen →
   beginnt wieder bei Screen 0 (Staleness-Guard greift).
7. Log-Einträge (`extended`/`exited`) landen im App-Group-Speicher.

## F. Roadmap (Kontext — NICHT Teil dieses Specs)

1. Fundament & Berechtigung — fertig (TP1)
2. Blockier-Kern — fertig & geräte-verifiziert (TP2)
3. **Reflexions-Erlebnis** ← dieses Dokument
4. **Dashboard & Persistenz:** Visualisierung der Reflexions-Logs, Emotions-Tracking, Statistiken
5. **Gamification:** progressive/levelabhängige Timer, Level, Streaks

## G. Abgrenzung (explizit NICHT in TP3)

- Keine progressiven/levelabhängigen Timer — das Fenster ist fix 5 Min (TP5)
- Kein Dashboard, keine Visualisierung der Logs (TP4)
- Keine Pro-App-Reflexion (gemeinsames Kontingent bleibt)
- Kein animiertes/interaktives Schild (Plattform-Grenze)
- Kein SwiftData — Reflexions-Log liegt wie die TP2-Regel in App-Group-`UserDefaults`
