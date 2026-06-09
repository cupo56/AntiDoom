# Design: Visuelles Konzept — „Ruhig & Minimal"

**Datum:** 2026-06-10
**Status:** Genehmigt
**App:** AntiDoom (siehe `README.md`)
**Visuelle Referenz:** `docs/superpowers/design-reference/art-directions.html`, `docs/superpowers/design-reference/app-home-light-dark.html` (im Browser öffnen)

## Zweck & Geltungsbereich

Dieses Dokument legt die **visuelle Design-Sprache** von AntiDoom verbindlich fest:
Stimmung, Farben, Typografie, Form, Markenmotiv und Tonfall. Es ist ein
**Referenz-Dokument**, das alle weiteren funktionalen Teilprojekte (Blockier-Kern,
Reflexions-Erlebnis, Dashboard, Gamification) konsumieren — nicht ein einzelnes
Feature. Es beschreibt **kein** konkretes Screen-Layout über die gezeigten
Beispiele hinaus.

Die Sprache wurde über zwei Oberflächen validiert: den **Schild** (Sperr-Screen
über der blockierten App) und den **Haupt-App-Startbildschirm**, jeweils in Hell
und Dunkel.

## Grundstimmung

Entschleunigt, urteilsfrei, achtsam — Anmutung einer Meditations-App
(Calm/Headspace). AntiDoom unterbricht den unbewussten Scroll-Autopiloten **sanft**
und holt zurück ins Hier und Jetzt; es schimpft nicht und beschämt nicht. Jede
visuelle Entscheidung dient Ruhe, Klarheit und Wärme.

Gewählt aus drei Richtungen (A „Ruhig & Minimal" vs. B „Klar & Konfrontativ" vs.
C „Warm & Menschlich"); A wurde bestätigt.

## Farben (Design-Tokens)

Hell und Dunkel werden **beide** unterstützt; die App folgt automatisch der
System-Einstellung des iPhones. Token-Namen sind verbindlich; Hex-Werte sind der
Startwert.

| Token | Rolle | Hell | Dunkel |
|---|---|---|---|
| `canvas` | App-Hintergrund | `#F4F2EC` | `#141815` |
| `surface` | Karten/erhöhte Flächen | `#FBFAF6` | `#1F2522` |
| `border` | Trennlinien/Rahmen | `#E8E6DD` | `#2B322E` |
| `ink` | Primärtext | `#1D2A30` | `#E9E7DF` |
| `inkMuted` | Sekundärtext | `#8A948F` | `#888F88` |
| `accent` | Akzent (Salbei) | `#7E9B82` | `#8FB093` |
| `onAccent` | Text auf Akzent | `#FFFFFF` | `#FFFFFF` |

Der Akzent ist im Dunkelmodus leicht aufgehellt (`#8FB093`), damit der Kontrast
auf dunklem Grund stimmt. Akzent trägt: Primär-Buttons, Level-/Statuswerte, das
Markenmotiv und kleine Hervorhebungen — sparsam einsetzen, damit Ruhe bleibt.

## Typografie

- **Display/Überschriften:** **New York** (iOS-System-Serif), Semibold. Wirkt
  ruhig, menschlich, „editorial". Verwendet für Headlines, Reflexionsfragen und
  die große Level-Zahl.
- **Fließtext & UI:** **SF Pro** (System-Sans). Legibel, nativ, unaufdringlich.
  Verwendet für Body, Buttons, Labels, Statistik-Kleinwerte.
- **Labels (Mikro):** SF Pro, 11 px, `letter-spacing` ~1 px, GROSSBUCHSTABEN, in
  `inkMuted` — für Sektionsüberschriften wie „GESCHÜTZTE APPS".

In SwiftUI: `Font.custom` mit der „New York"-Familie bzw. `.system(..., design:
.serif)` für Display; Standard-`.system` für Body.

## Markenmotiv — der „Atem-Ring"

Ein **dünner Salbei-Kreis** (`accent`, ~2 px Linie) ist die wiederkehrende
Signatur der App:
- Auf dem Home-Screen trägt er die **Willenskraft-Stufe** (große Serif-Zahl in
  der Mitte).
- Auf dem **Schild** ist er der ruhige Fokuspunkt über der Reflexionsfrage.
- Er darf später dezent „atmen" (langsame Skalierungs-/Opacity-Animation) — als
  beruhigender, zur Entschleunigung einladender Akzent. Animation ist optional
  und nicht Teil der ersten Umsetzung.

## Form & Raum

- Großzügig gerundete Ecken: Karten/Container ~16 px, Buttons ~14 px, Pillen/
  Ringe voll rund.
- Viel Weißraum, luftige Innenabstände (Container-Padding ~20–30 px).
- Flache Flächen mit feinen 1-px-`border`-Linien statt harter Schatten; Schatten
  nur sehr weich, falls überhaupt.

## Ikonografie

SF Symbols in dünnem/regulärem Gewicht, eingefärbt in `accent` oder `inkMuted`.
Keine schweren, vollflächigen Icons — die Linienführung bleibt leicht.

## Tonfall (Text)

Warm, in **zweiter Person**, ermutigend statt streng. Fragen statt Befehle:
„Bringt dir das gerade wirklich etwas?" / „Was brauchst du gerade?" — nie
„GESPERRT" o. ä. Grounding-Aufgaben sind einladend formuliert („Nenne 3 Dinge, die
du gerade um dich herum siehst."). Der Tonfall ist Teil der Markenidentität und
gilt für alle nutzersichtbaren Texte.

## Konsequenzen für die Umsetzung (Hinweise, nicht Teil dieses Specs)

- Die Tokens sollten als **zentrale SwiftUI-Theme-Schicht** kodiert werden
  (Farb-Assets mit Light/Dark-Varianten im Asset-Katalog + ein `Theme`/Font-Helfer
  + wiederverwendbare Komponenten: Atem-Ring, Primär-Button, Karte, Listenzeile),
  damit Teilprojekt 2+ dagegen bauen. Ob das **jetzt** als eigenes kleines
  Teilprojekt umgesetzt wird oder organisch beim Bau von Teilprojekt 2 entsteht,
  ist eine offene Entscheidung (mit dem Nutzer zu klären).
- Der **Schild** läuft in der `ShieldConfiguration`-Extension und hat dort einen
  eingeschränkten UI-Kontext (`ShieldConfiguration`-Properties: Hintergrund,
  Titel, Untertitel, Buttons), kein freies SwiftUI. Die Design-Sprache muss
  innerhalb dieser API so nah wie möglich nachgebildet werden (Salbei-Akzent,
  ruhige Typo, Atem-Ring ggf. als Bild/Icon).

## Abgrenzung (explizit NICHT in diesem Konzept)

- Keine fertigen Screen-Layouts/Flows der einzelnen Features (gehören in deren
  Teilprojekte)
- Keine App-Icon-Gestaltung (separat)
- Keine Motion-/Animations-Spezifikation über den Hinweis zum Atem-Ring hinaus
- Keine Implementierung — dieses Dokument ist reine Design-Referenz
