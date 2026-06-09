# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AntiDoom is an iOS app that acts as a psychological mindfulness barrier ("Türsteher") against doom-scrolling. It uses Apple's official Screen Time APIs to block social media apps and replace them with reflective micro-exercises instead of a simple "blocked" message.

## Build & Run

Xcode project targeting iOS (deployment target 26.5, Xcode 26.5). Three targets:
`AntiDoom` (app) + `DeviceActivityMonitor` + `ShieldConfiguration` (app extensions).

```bash
# Autonomous verification build — compiles app + both extensions for the
# simulator WITHOUT code signing (the canonical green-gate after any change).
./scripts/build-sim.sh

# On-device build/run (real iPhone) must be done from Xcode: the Family
# Controls / DeviceActivity / ManagedSettings frameworks do not function in the
# simulator and the family-controls entitlement requires a provisioning profile.
```

`scripts/build-sim.sh` runs `xcodebuild -scheme AntiDoom -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO clean build`. There is no unit-test target yet; the build is the verification gate. On-device checks live in `docs/superpowers/device-test-checklist-fundament.md`.

### Editing the Xcode project
`AntiDoom.xcodeproj/project.pbxproj` is `objectVersion 77` (FileSystemSynchronizedRootGroup format). Do NOT hand-edit it. Add targets/build-settings via the Ruby `xcodeproj` gem — see `scripts/pbxproj/` (notably `add_extension.rb`, which is idempotent and also embeds the `.appex` into the app). New extension targets MUST set `PRODUCT_NAME = $(TARGET_NAME)` or the product wrapper resolves to a bare `.appex` and the build collides.

## Architecture

The foundation (Teilprojekt 1) exists; blocking/reflection/dashboard/gamification are future sub-projects. Specs and plans live under `docs/superpowers/`.

### Apple Frameworks
- **FamilyControls** — authorization (`AuthorizationCenter`, requested in `ContentView`)
- **DeviceActivity** — monitors usage, triggers blocking (skeleton `DeviceActivityMonitorExtension`, no logic yet)
- **ManagedSettings / ManagedSettingsUI** — the shield overlay (skeleton `ShieldConfigurationExtension`, returns default `ShieldConfiguration` for now)

### Data Layer
- **SwiftData** — local-only storage; `Shared/SharedStore.swift` builds the `ModelContainer` in the App Group container (`group.antidoom.AntiDoom`) so app and extensions share one DB. Shared code lives in the plain `Shared/` group, compiled into all three targets.
- Current model is a minimal `FoundationProbe` (proves the shared store); real models come later.
- All three targets carry the App Group + `com.apple.developer.family-controls` entitlements.
- **Note:** `FamilyActivityPicker` returns opaque `ApplicationToken`s — no readable app names/bundle IDs. Future models store tokens, not names.

### Core User Flow
1. User sets usage limits per app in the main dashboard
2. DeviceActivity monitor fires when a limit is reached
3. ShieldConfiguration extension renders the reflection exercise over the blocked app
4. User completes a grounding prompt to earn a short extension window, or exits
5. Responses and outcomes are written to SwiftData for the emotions/progress dashboard

### Planned Data Models (replacing the minimal `FoundationProbe`)
- `ReflectionSession` — timestamp, triggering app, prompt shown, user response, outcome (extended / exited)
- `UsageRule` — target app, daily limit, interval schedule, current level
- `ProgressRecord` — streak, resistance count, level, weekly summaries
