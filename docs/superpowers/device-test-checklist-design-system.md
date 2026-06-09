# Sicht-Check — Design System

Nur visuell prüfbar (Xcode Canvas / Gerät), nicht durch den Compile-Gate:

1. **In Xcode** `AntiDoom/DesignSystem/StyleGuideView.swift` öffnen, Canvas
   aktivieren. Erwartung: zwei Previews ("Hell" und "Dunkel") zeigen Headline
   (Serif), Atem-Ring mit Level 4, Geschützte-Apps-Karte mit Zeilen, eine Karte
   und beide Buttons — alles in Salbei-Akzent auf ruhigem Hintergrund.
2. **Hell vs. Dunkel** vergleichen: Hintergrund wechselt von `#F4F2EC` zu
   `#141815`, Text bleibt gut lesbar, Akzent ist im Dunkeln etwas heller.
3. `AntiDoom/ContentView.swift` Canvas: Der Berechtigungs-Screen nutzt jetzt
   Atem-Ring, Serif-Titel und den Primär-Button.
4. Optional auf echtem iPhone starten und System-Hell/Dunkel umschalten — die App
   folgt automatisch.

Melde zurück, ob Hell und Dunkel so wirken wie gewünscht.
