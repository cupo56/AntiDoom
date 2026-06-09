# Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encode AntiDoom's approved "Ruhig & Minimal" visual concept into a reusable SwiftUI design system (color/type/spacing tokens + core components) that later feature sub-projects build against.

**Architecture:** Pure-code design tokens (light/dark via dynamic `UIColor`, no asset catalog) plus small, focused SwiftUI component views and button styles. All files live under `AntiDoom/DesignSystem/`; because `AntiDoom/` is a `PBXFileSystemSynchronizedRootGroup`, new files are auto-included in the app target with NO `project.pbxproj` changes. A `StyleGuideView` with light + dark `#Preview`s serves as living documentation and the visual-check surface.

**Tech Stack:** Swift / SwiftUI, UIKit (`UIColor` dynamic provider). No new targets, no asset catalog, no test target.

**Reference spec:** `docs/superpowers/specs/2026-06-10-visuelles-konzept-design.md`
**Visual reference:** `docs/superpowers/design-reference/app-home-light-dark.html`

**Verification model (read this):** Consistent with the foundation sub-project, the autonomous gate is a clean compile: `./scripts/build-sim.sh` ending in `** BUILD SUCCEEDED **`. These are pure-visual components with no branching logic, so there are no unit tests (a snapshot-test target would be disproportionate). Visual correctness is confirmed by the user opening `StyleGuideView` in Xcode's Canvas (light + dark) — captured in Task 7.

**Token values (single source of truth — used verbatim in Task 1):**

| Token | Light | Dark |
|---|---|---|
| canvas | `0xF4F2EC` | `0x141815` |
| surface | `0xFBFAF6` | `0x1F2522` |
| border | `0xE8E6DD` | `0x2B322E` |
| ink | `0x1D2A30` | `0xE9E7DF` |
| inkMuted | `0x8A948F` | `0x888F88` |
| accent | `0x7E9B82` | `0x8FB093` |
| onAccent | white | white |

---

## Task 1: Design tokens (`Theme`)

**Files:**
- Create: `AntiDoom/DesignSystem/Theme.swift`

- [ ] **Step 1: Create the token layer**

Create `AntiDoom/DesignSystem/Theme.swift`:

```swift
//  Theme.swift
//  AntiDoom design system — single source of truth for colors, type, spacing.
//  Visual concept: docs/superpowers/specs/2026-06-10-visuelles-konzept-design.md

import SwiftUI

enum Theme {

    enum Colors {
        static let canvas   = dynamic(light: 0xF4F2EC, dark: 0x141815)
        static let surface  = dynamic(light: 0xFBFAF6, dark: 0x1F2522)
        static let border   = dynamic(light: 0xE8E6DD, dark: 0x2B322E)
        static let ink      = dynamic(light: 0x1D2A30, dark: 0xE9E7DF)
        static let inkMuted = dynamic(light: 0x8A948F, dark: 0x888F88)
        static let accent   = dynamic(light: 0x7E9B82, dark: 0x8FB093)
        static let onAccent = Color.white

        private static func dynamic(light: UInt, dark: UInt) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(rgb: dark)
                    : UIColor(rgb: light)
            })
        }
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat = 12
        static let m: CGFloat = 20
        static let l: CGFloat = 30
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 14
    }

    enum Fonts {
        /// Serif display (New York on iOS) for headlines, prompts, the level number.
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .serif)
        }
        /// Sans body/UI text (SF Pro).
        static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
        /// Micro uppercase label (use with .tracking and .textCase in SectionLabel).
        static func label() -> Font {
            .system(size: 11, weight: .semibold)
        }
    }
}

private extension UIColor {
    /// 0xRRGGBB → opaque UIColor.
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
```

- [ ] **Step 2: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`. (Clean build; may take a few minutes.)

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/DesignSystem/Theme.swift
git commit -m "feat(design-system): color, type, spacing tokens"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Task 2: `SectionLabel` + `Card`

**Files:**
- Create: `AntiDoom/DesignSystem/SectionLabel.swift`
- Create: `AntiDoom/DesignSystem/Card.swift`

- [ ] **Step 1: Create the section label**

Create `AntiDoom/DesignSystem/SectionLabel.swift`:

```swift
//  SectionLabel.swift
//  Micro uppercase label, e.g. "GESCHÜTZTE APPS".

import SwiftUI

struct SectionLabel: View {
    private let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.Fonts.label())
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.inkMuted)
    }
}

#Preview {
    SectionLabel("Geschützte Apps")
        .padding()
        .background(Theme.Colors.canvas)
}
```

- [ ] **Step 2: Create the card container**

Create `AntiDoom/DesignSystem/Card.swift`:

```swift
//  Card.swift
//  Rounded surface container with a hairline border (no heavy shadow).

import SwiftUI

struct Card<Content: View>: View {
    private let padded: Bool
    private let content: Content

    /// - Parameter padded: apply standard inner padding. Set false when the
    ///   content manages its own insets (e.g. a list of full-width rows).
    init(padded: Bool = true, @ViewBuilder content: () -> Content) {
        self.padded = padded
        self.content = content()
    }

    var body: some View {
        content
            .padding(padded ? Theme.Spacing.m : 0)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
}

#Preview {
    Card {
        Text("Inhalt").font(Theme.Fonts.body()).foregroundStyle(Theme.Colors.ink)
    }
    .padding()
    .background(Theme.Colors.canvas)
}
```

- [ ] **Step 3: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add AntiDoom/DesignSystem/SectionLabel.swift AntiDoom/DesignSystem/Card.swift
git commit -m "feat(design-system): SectionLabel and Card components"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Task 3: Button styles

**Files:**
- Create: `AntiDoom/DesignSystem/ButtonStyles.swift`

- [ ] **Step 1: Create the primary and secondary button styles**

Create `AntiDoom/DesignSystem/ButtonStyles.swift`:

```swift
//  ButtonStyles.swift
//  Primary (filled sage) and secondary (muted text) button styles.

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(15, weight: .semibold))
            .foregroundStyle(Theme.Colors.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body(13))
            .foregroundStyle(Theme.Colors.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

#Preview {
    VStack(spacing: 16) {
        Button("Schließen") {}.buttonStyle(.primary)
        Button("2 Minuten verlängern") {}.buttonStyle(.secondary)
    }
    .padding()
    .background(Theme.Colors.canvas)
}
```

- [ ] **Step 2: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/DesignSystem/ButtonStyles.swift
git commit -m "feat(design-system): primary and secondary button styles"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Task 4: `BreathingRing` (brand motif)

**Files:**
- Create: `AntiDoom/DesignSystem/BreathingRing.swift`

- [ ] **Step 1: Create the ring component**

Create `AntiDoom/DesignSystem/BreathingRing.swift`:

```swift
//  BreathingRing.swift
//  The recurring brand motif: a thin sage ring with optional centered content.
//  (Breathing animation is intentionally deferred — see visual concept spec.)

import SwiftUI

struct BreathingRing<Content: View>: View {
    private let size: CGFloat
    private let lineWidth: CGFloat
    private let content: Content

    init(size: CGFloat = 116, lineWidth: CGFloat = 2, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.size = size
        self.lineWidth = lineWidth
        self.content = content()
    }

    var body: some View {
        Circle()
            .stroke(Theme.Colors.accent, lineWidth: lineWidth)
            .frame(width: size, height: size)
            .overlay { content }
    }
}

#Preview {
    BreathingRing {
        VStack(spacing: 2) {
            Text("4").font(Theme.Fonts.display(34)).foregroundStyle(Theme.Colors.ink)
            Text("LEVEL").font(Theme.Fonts.label()).tracking(1).foregroundStyle(Theme.Colors.inkMuted)
        }
    }
    .padding()
    .background(Theme.Colors.canvas)
}
```

- [ ] **Step 2: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/DesignSystem/BreathingRing.swift
git commit -m "feat(design-system): BreathingRing brand motif"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Task 5: `ListRow`

**Files:**
- Create: `AntiDoom/DesignSystem/ListRow.swift`

- [ ] **Step 1: Create the list row**

Create `AntiDoom/DesignSystem/ListRow.swift`:

```swift
//  ListRow.swift
//  Single row for lists inside a Card: optional leading SF Symbol, title,
//  optional trailing accent text.

import SwiftUI

struct ListRow: View {
    private let icon: String?
    private let title: String
    private let trailing: String?

    init(icon: String? = nil, title: String, trailing: String? = nil) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 30, height: 30)
            }
            Text(title)
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.Fonts.body(12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
    }
}

#Preview {
    Card(padded: false) {
        VStack(spacing: 0) {
            ListRow(icon: "camera", title: "Instagram", trailing: "15 Min/Tag")
            Divider().overlay(Theme.Colors.border)
            ListRow(icon: "music.note", title: "TikTok", trailing: "10 Min/Tag")
        }
    }
    .padding()
    .background(Theme.Colors.canvas)
}
```

- [ ] **Step 2: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/DesignSystem/ListRow.swift
git commit -m "feat(design-system): ListRow component"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Task 6: `StyleGuideView` (living documentation)

**Files:**
- Create: `AntiDoom/DesignSystem/StyleGuideView.swift`

- [ ] **Step 1: Create the style guide screen**

Create `AntiDoom/DesignSystem/StyleGuideView.swift`:

```swift
//  StyleGuideView.swift
//  Living documentation: shows every design-system token and component on the
//  canvas, in both light and dark previews. Not wired into the app's navigation.

import SwiftUI

struct StyleGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {

                Text("Bringt dir das gerade wirklich etwas?")
                    .font(Theme.Fonts.display(25))
                    .foregroundStyle(Theme.Colors.ink)

                Text("Atme einmal durch. Nenne 3 Dinge, die du gerade um dich herum siehst.")
                    .font(Theme.Fonts.body(14))
                    .foregroundStyle(Theme.Colors.inkMuted)

                BreathingRing {
                    VStack(spacing: 2) {
                        Text("4").font(Theme.Fonts.display(34)).foregroundStyle(Theme.Colors.ink)
                        Text("LEVEL").font(Theme.Fonts.label()).tracking(1).foregroundStyle(Theme.Colors.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionLabel("Geschützte Apps")
                    Card(padded: false) {
                        VStack(spacing: 0) {
                            ListRow(icon: "camera", title: "Instagram", trailing: "15 Min/Tag")
                            Divider().overlay(Theme.Colors.border)
                            ListRow(icon: "music.note", title: "TikTok", trailing: "10 Min/Tag")
                            Divider().overlay(Theme.Colors.border)
                            ListRow(icon: "play.rectangle", title: "YouTube", trailing: "20 Min/Tag")
                        }
                    }
                }

                Card {
                    Text("Eine Karte mit Inhalt.")
                        .font(Theme.Fonts.body())
                        .foregroundStyle(Theme.Colors.ink)
                }

                VStack(spacing: Theme.Spacing.xs) {
                    Button("Schließen") {}.buttonStyle(.primary)
                    Button("2 Minuten verlängern") {}.buttonStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .background(Theme.Colors.canvas)
    }
}

#Preview("Hell") {
    StyleGuideView().preferredColorScheme(.light)
}

#Preview("Dunkel") {
    StyleGuideView().preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/DesignSystem/StyleGuideView.swift
git commit -m "feat(design-system): StyleGuideView living documentation"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Task 7: Apply the theme to the existing authorization screen

Prove the design system on a real screen: restyle `ContentView` (currently ad-hoc `.tint`/system colors) with the tokens and components.

**Files:**
- Modify: `AntiDoom/ContentView.swift`

- [ ] **Step 1: Restyle ContentView with the design system**

Replace the ENTIRE contents of `AntiDoom/ContentView.swift` with:

```swift
//  ContentView.swift
//  AntiDoom

import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var errorMessage: String?

    var body: some View {
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
                .foregroundStyle(isApproved ? Theme.Colors.accent : Theme.Colors.inkMuted)

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if !isApproved {
                Button("Berechtigung anfragen") {
                    Task { await requestAuthorization() }
                }
                .buttonStyle(.primary)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.canvas)
        .onAppear { status = AuthorizationCenter.shared.authorizationStatus }
    }

    private var isApproved: Bool {
        status == .approved || status == .approvedWithDataAccess
    }

    private var statusText: String {
        switch status {
        case .notDetermined: return "Berechtigung noch nicht erteilt"
        case .denied: return "Berechtigung verweigert"
        case .approved, .approvedWithDataAccess: return "Berechtigung erteilt ✓"
        @unknown default: return "Unbekannter Status"
        }
    }

    private func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            errorMessage = nil
        } catch {
            errorMessage = "Anfrage fehlgeschlagen: \(error.localizedDescription)"
        }
        status = AuthorizationCenter.shared.authorizationStatus
    }
}

#Preview("Hell") {
    ContentView().preferredColorScheme(.light)
}

#Preview("Dunkel") {
    ContentView().preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/ContentView.swift
git commit -m "feat(design-system): restyle authorization screen with tokens"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Task 8: Visual confirmation note (user)

The design system compiles; visual correctness is a human check.

**Files:**
- Create: `docs/superpowers/device-test-checklist-design-system.md`

- [ ] **Step 1: Write the checklist**

Create `docs/superpowers/device-test-checklist-design-system.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/device-test-checklist-design-system.md
git commit -m "docs: visual-check checklist for design system"
```
End the commit body with:
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>

---

## Done criteria

- `./scripts/build-sim.sh` ends with `** BUILD SUCCEEDED **`
- `AntiDoom/DesignSystem/` contains: `Theme.swift`, `SectionLabel.swift`, `Card.swift`, `ButtonStyles.swift`, `BreathingRing.swift`, `ListRow.swift`, `StyleGuideView.swift`
- `ContentView` is restyled with the tokens (proves the system on a real screen)
- The user has the visual-check checklist to confirm light/dark in Xcode Canvas
