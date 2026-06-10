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
