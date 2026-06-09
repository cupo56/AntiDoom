# AntiDoom

Die App AntiDoom fungiert als psychologische Achtsamkeits-Schranke – ein digitaler „Türsteher". Das Ziel ist nicht, Apps dauerhaft zu sperren, sondern den unbewussten kognitiven Autopiloten beim Scrollen zu unterbrechen. Der Nutzer soll sanft aus der digitalen Trance zurück ins „Hier und Jetzt" geholt werden.

---

## Das UX- & Interventions-Konzept

* **Die Reiz-Schranke (Das Schild):** Nach Ablauf einer definierten Nutzungszeit – oder in festen Intervallen – legt sich ein vollflächiges Schild über die jeweilige Social-Media-App (z. B. Instagram, TikTok) und blockiert sie sofort.
* **Micro-Friction statt Frustration:** Um das Schild aufzulösen oder ein kurzes Verlängerungs-Zeitfenster freizuschalten, muss der Nutzer aktiv kognitiven Aufwand betreiben.
* **Die Reflexions-Übung:** Anstelle einer schlichten „Gesperrt"-Meldung begegnet dem Nutzer Folgendes:
  * *Wachrüttelnde, produktive Impulse:* Kurze Fragen, die den aktuellen Mehrwert hinterfragen – z. B. „Bringt dir dieser Inhalt gerade wirklich etwas?"
  * *Persönliche Fragen & Grounding-Übungen:* Der Nutzer beantwortet aktiv eine Frage, um sein Bewusstsein zu schärfen – z. B. „Welches Gefühl versuchst du gerade zu betäuben?" oder „Nenne 3 Dinge in deiner unmittelbaren Umgebung."

---

## Progressives Training & Gamification

* **Dynamischer Timer (Level-System):** Die App passt sich dem individuellen Fortschritt an. Blockadezeiten und geforderte Pausen werden schrittweise erhöht – z. B. von Woche zu Woche –, um die Aufmerksamkeitsspanne gezielt zu trainieren.
* **Ehrliche Statistiken (Dashboard):** Der Fortschritt wird klar visualisiert. Der Nutzer sieht schwarz auf weiß, wie oft er der Versuchung widerstanden hat – z. B. „Deine Willenskraft ist heute auf Level 4."
* **Emotions-Tracking:** Eine Langzeitauswertung zeigt, aus welchen Mustern heraus (Langeweile, Stress, Müdigkeit) der Nutzer am häufigsten in die Doom-Scroll-Falle tappt.

---

## Nativer Schutz über Apple APIs

Die Umsetzung erfolgt sauber und App-Store-konform über die offiziellen iOS-Schnittstellen für Bildschirmzeit – **FamilyControls** & **DeviceActivity**. Das Hintergrund-Tracking ist dabei äußerst akkuschonend.

* **Blockier-Logik:** Sobald das Limit greift, injiziert eine System-Erweiterung (`ShieldConfiguration`) die Schranke direkt über die blockierte App.
* **Lokale Datenhaltung (SwiftData):** Für die reine Blockierfunktion ist keine Datenbank erforderlich. Reflexionsantworten, emotionale Muster und Fortschrittsstatistiken werden lokal und sicher auf dem iPhone mittels SwiftData – dem modernen Nachfolger von Core Data – gespeichert.
* **Brücke zwischen App & Schranke:** Über eine gemeinsame App Group können sowohl die Blockier-Schranke als auch das Haupt-Dashboard auf dieselbe SwiftData-Datenbank zugreifen.