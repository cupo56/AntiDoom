# Geräte-Test-Checkliste — Fundament & Berechtigung

Diese Schritte kann nur der Nutzer auf einem echten iPhone prüfen
(Simulator/CI können es nicht). In Xcode ausführen:

1. **Signing einrichten:** Projekt in Xcode öffnen, für jedes der drei Targets
   (AntiDoom, DeviceActivityMonitor, ShieldConfiguration) unter
   "Signing & Capabilities" das Team `7PPXXRWMCT` wählen und sicherstellen, dass
   die Capabilities **App Groups** (`group.antidoom.AntiDoom`) und
   **Family Controls** vorhanden sind. Xcode legt die Provisioning-Profile an.
2. **Auf echtem iPhone bauen & starten** (echtes Gerät als Run-Destination).
   Erwartung: App startet, Status-Screen zeigt "Berechtigung noch nicht erteilt".
3. **"Berechtigung anfragen" tippen.** Erwartung: System-Dialog für
   Bildschirmzeit/Family Controls erscheint; nach Zustimmung wechselt der Status
   auf "Berechtigung erteilt ✓".
4. **Extensions eingebettet?** In Xcode unter dem gebauten Produkt (oder via
   Organizer) prüfen, dass die App beide `.appex` enthält. Alternativ: App
   installiert ohne Signing-Fehler → Einbettung ok.
5. **App-Group-Pfad (optional):** In `SharedStore` testweise den Container-URL
   loggen und prüfen, dass er den Pfad `.../Shared Containers/AppGroup/...`
   für `group.antidoom.AntiDoom` enthält.

Bitte Ergebnis der Schritte 2–4 zurückmelden — damit ist das Fundament bestätigt.
