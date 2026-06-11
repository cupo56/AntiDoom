# Geräte-Test-Checkliste — Reflexions-Erlebnis (TP3)

Nur auf echtem iPhone prüfbar (Screen-Time-Frameworks haben im Simulator nur
Stubs). Autonomer Gate war ausschließlich der Simulator-Compile.

**Vorbereitung:** Blockier-Regel aus TP2 aktiv, Tageslimit zum Testen auf 5 Min,
Limit erreichen, damit das Schild steht.

## Schritte

- [ ] **1. Gebrandetes Schild:** Bei erreichtem Limit erscheint das ruhige
      „Kurz innehalten"-Schild mit Ring-Icon und einem Prompt — NICHT das
      System-„Restricted".
- [ ] **2. (LOAD-BEARING) `.defer`-Re-Render:** „Durchatmen" tippen → das Schild
      wechselt zu Screen 2 („Atme dreimal tief durch"). Falls es stattdessen
      schließt/hängt: dokumentierter `.defer`-Wackler — vermerken.
- [ ] **3. Unlock:** Auf Screen 2 „Ich bin bereit" → App wird nutzbar (ggf. App
      erneut öffnen; nach `.close` landet man kurz auf Home).
- [ ] **4. (LOAD-BEARING) Re-Block nach Nutzung:** Nach ~5 Min echter Nutzung
      legt sich das Schild wieder über die App (Fenster-Schwelle; grobe
      Auflösung erwartbar). Pausieren/Weglegen sollte die 5 Min verlängern
      (Nutzungszeit, nicht Uhrzeit).
- [ ] **5. Exit:** Schild → „Beenden" → Home-Screen, App bleibt gesperrt.
- [ ] **6. Staleness-Guard:** „Durchatmen" (Screen 2) → App verlassen → >2 Min
      warten → App erneut öffnen. Erwartung: Schild beginnt wieder bei Screen 0,
      nicht out-of-context bei Screen 2.
- [ ] **7. Prompt-Rotation:** Über mehrere Schild-Episoden hinweg wechseln die
      Prompts (Zufallsauswahl).

## Ergebnis zurückmelden
Besonders 2 und 4 entscheiden, ob die gestufte Reibung und der Re-Block tragen.
