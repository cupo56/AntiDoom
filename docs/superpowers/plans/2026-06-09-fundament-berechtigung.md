# Fundament & Berechtigung — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the technical foundation for AntiDoom — App Group, shared SwiftData store, FamilyControls authorization, and two correctly-wired app-extension targets — with no user-visible blocking feature yet.

**Architecture:** A single Xcode project with three targets (main app `AntiDoom` + `DeviceActivityMonitor` + `ShieldConfiguration` extensions). Shared code lives in a plain `Shared/` group compiled into all three targets. Target/embed/dependency surgery on `project.pbxproj` is done with the canonical `xcodeproj` Ruby library via committed, re-runnable scripts. Verification is a non-signing iOS-Simulator build (`CODE_SIGNING_ALLOWED=NO`) — device signing and runtime behaviour are verified by the user on a real iPhone.

**Tech Stack:** Swift / SwiftUI, SwiftData, FamilyControls, DeviceActivity, ManagedSettings, ManagedSettingsUI; Ruby `xcodeproj` gem 1.27.0; `xcodebuild`.

**Reference spec:** `docs/superpowers/specs/2026-06-09-fundament-berechtigung-design.md`

**Constants used throughout:**
- App Group ID: `group.antidoom.AntiDoom`
- Development Team: `7PPXXRWMCT`
- iOS deployment target: `26.5`
- App bundle ID: `antidoom.AntiDoom`

---

## Task 1: Baseline build + tooling

Establish the autonomous verification command and confirm the untouched project builds green before any change.

**Files:**
- Create: `scripts/build-sim.sh`

- [ ] **Step 1: Ensure the `xcodeproj` gem is installed**

Run: `gem install --user-install xcodeproj && ruby -e "require 'xcodeproj'; puts Xcodeproj::VERSION"`
Expected: prints a version like `1.27.0` (already installed in this environment).

- [ ] **Step 2: Confirm the scheme name xcodebuild sees**

Run: `xcodebuild -project AntiDoom.xcodeproj -list`
Expected: output lists a scheme named `AntiDoom`. (If it differs, use that name in `scripts/build-sim.sh`.)

- [ ] **Step 3: Create the autonomous build script**

Create `scripts/build-sim.sh`:

```bash
#!/usr/bin/env bash
# Autonomous verification build: compiles the app + all extensions for the iOS
# Simulator WITHOUT code signing. Signing and on-device runtime behaviour are
# verified separately by the user on a real iPhone (see device-test checklist).
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild \
  -project AntiDoom.xcodeproj \
  -scheme AntiDoom \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

- [ ] **Step 4: Make it executable and run the baseline build**

Run: `chmod +x scripts/build-sim.sh && ./scripts/build-sim.sh`
Expected: ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Ignore the build output directory**

Append `build/` to `.gitignore` (create the file if absent). Final line present: `build/`

- [ ] **Step 6: Commit**

```bash
git add scripts/build-sim.sh .gitignore
git commit -m "build: add non-signing simulator build script for verification"
```

---

## Task 2: Main-app entitlements (App Group + Family Controls)

**Files:**
- Create: `AntiDoom/AntiDoom.entitlements`
- Create: `scripts/pbxproj/01_app_entitlements.rb`
- Modify: `AntiDoom.xcodeproj/project.pbxproj` (via script)

- [ ] **Step 1: Create the app entitlements file**

Create `AntiDoom/AntiDoom.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.family-controls</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.antidoom.AntiDoom</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Create the script that points the app target at the entitlements file**

Create `scripts/pbxproj/01_app_entitlements.rb`:

```ruby
#!/usr/bin/env ruby
# Sets CODE_SIGN_ENTITLEMENTS on the AntiDoom app target for both configs.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
app = project.targets.find { |t| t.name == 'AntiDoom' } or abort 'AntiDoom target not found'

app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'AntiDoom/AntiDoom.entitlements'
end

project.save
puts 'Set CODE_SIGN_ENTITLEMENTS on AntiDoom.'
```

- [ ] **Step 3: Run the script**

Run: `ruby scripts/pbxproj/01_app_entitlements.rb`
Expected: prints `Set CODE_SIGN_ENTITLEMENTS on AntiDoom.`

- [ ] **Step 4: Verify the build still succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`. (The entitlements file is present but signing is skipped, so it does not gate the build.)

- [ ] **Step 5: Commit**

```bash
git add AntiDoom/AntiDoom.entitlements scripts/pbxproj/01_app_entitlements.rb AntiDoom.xcodeproj/project.pbxproj
git commit -m "feat: add App Group + Family Controls entitlements to app target"
```

---

## Task 3: Shared SwiftData store + minimal model

Replace the template `Item` with a shared store wired through a plain `Shared/` group (compilable into every target later).

**Files:**
- Create: `Shared/FoundationProbe.swift`
- Create: `Shared/SharedStore.swift`
- Create: `scripts/pbxproj/02_add_shared.rb`
- Delete: `AntiDoom/Item.swift`
- Modify: `AntiDoom/AntiDoomApp.swift`

- [ ] **Step 1: Create the minimal foundation model**

Create `Shared/FoundationProbe.swift`:

```swift
//  FoundationProbe.swift
//  Minimal model that exists only to prove the shared App Group store works.
//  Real domain models (sessions, rules, stats) are added in later sub-projects.

import Foundation
import SwiftData

@Model
final class FoundationProbe {
    var createdAt: Date

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 2: Create the shared store helper**

Create `Shared/SharedStore.swift`:

```swift
//  SharedStore.swift
//  Builds the SwiftData ModelContainer in the shared App Group container so the
//  main app and the extensions read/write the same database.

import Foundation
import SwiftData

enum SharedStore {
    static let appGroupID = "group.antidoom.AntiDoom"

    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([FoundationProbe.self])
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID)
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }()
}
```

- [ ] **Step 3: Delete the template model**

Run: `rm AntiDoom/Item.swift`
(`AntiDoom/` is a synchronized group, so deleting the file on disk removes it from the target automatically — no pbxproj edit needed.)

- [ ] **Step 4: Point the app at the shared container**

Replace the entire contents of `AntiDoom/AntiDoomApp.swift` with:

```swift
//  AntiDoomApp.swift
//  AntiDoom

import SwiftUI
import SwiftData

@main
struct AntiDoomApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedStore.container)
    }
}
```

- [ ] **Step 5: Create the script that adds the `Shared/` group to the app target**

Create `scripts/pbxproj/02_add_shared.rb`:

```ruby
#!/usr/bin/env ruby
# Creates a plain (non-synchronized) `Shared` group with explicit file references
# and adds the shared Swift sources to the AntiDoom app target's compile phase.
# Extension targets pick these same references up later via add_extension.rb.
require 'xcodeproj'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')
app = project.targets.find { |t| t.name == 'AntiDoom' } or abort 'AntiDoom target not found'

group = project.main_group.find_subpath('Shared', true)
group.set_path('Shared')

%w[SharedStore.swift FoundationProbe.swift].each do |name|
  next if group.files.any? { |f| f.display_name == name }
  ref = group.new_reference(name)
  app.add_file_references([ref])
end

project.save
puts 'Added Shared group and sources to AntiDoom target.'
```

- [ ] **Step 6: Run the script**

Run: `ruby scripts/pbxproj/02_add_shared.rb`
Expected: prints `Added Shared group and sources to AntiDoom target.`

- [ ] **Step 7: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add Shared scripts/pbxproj/02_add_shared.rb AntiDoom/AntiDoomApp.swift AntiDoom.xcodeproj/project.pbxproj
git commit -m "feat: shared App Group SwiftData store with minimal probe model"
```

---

## Task 4: FamilyControls authorization status screen

Replace the template item-list UI with a minimal authorization status + request screen.

**Files:**
- Modify: `AntiDoom/ContentView.swift`

- [ ] **Step 1: Replace the ContentView with an authorization screen**

Replace the entire contents of `AntiDoom/ContentView.swift` with:

```swift
//  ContentView.swift
//  AntiDoom

import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("AntiDoom")
                .font(.largeTitle.bold())

            Text(statusText)
                .font(.headline)
                .foregroundStyle(statusColor)

            if status != .approved {
                Button("Berechtigung anfragen") {
                    Task { await requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onAppear { status = AuthorizationCenter.shared.authorizationStatus }
    }

    private var statusText: String {
        switch status {
        case .notDetermined: return "Berechtigung noch nicht erteilt"
        case .denied: return "Berechtigung verweigert"
        case .approved: return "Berechtigung erteilt ✓"
        @unknown default: return "Unbekannter Status"
        }
    }

    private var statusColor: Color {
        switch status {
        case .approved: return .green
        case .denied: return .red
        default: return .secondary
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

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add AntiDoom/ContentView.swift
git commit -m "feat: FamilyControls authorization status screen"
```

---

## Task 5: Reusable extension-adder script

Write the parameterized script used by Tasks 6 and 7. No project change yet — this task only creates and reviews the script.

**Files:**
- Create: `scripts/pbxproj/add_extension.rb`

- [ ] **Step 1: Create the extension-adder script**

Create `scripts/pbxproj/add_extension.rb`:

```ruby
#!/usr/bin/env ruby
# Adds an iOS app-extension target to AntiDoom.xcodeproj, wires its Info.plist /
# entitlements / Swift source, adds the Shared/* sources to it, makes the app
# depend on it, and embeds the .appex into the app's PlugIns folder.
#
# Usage:
#   ruby scripts/pbxproj/add_extension.rb <TargetName> <BundleID> <PrincipalClass>
#
# Idempotent: re-running for an existing target is a no-op.
require 'xcodeproj'

target_name, bundle_id, principal = ARGV
unless target_name && bundle_id && principal
  abort 'usage: add_extension.rb <TargetName> <BundleID> <PrincipalClass>'
end

TEAM = '7PPXXRWMCT'
DEPLOYMENT = '26.5'

project = Xcodeproj::Project.open('AntiDoom.xcodeproj')

if project.targets.any? { |t| t.name == target_name }
  puts "Target #{target_name} already exists — skipping."
  exit 0
end

app = project.targets.find { |t| t.name == 'AntiDoom' } or abort 'AntiDoom target not found'

ext = project.new_target(:app_extension, target_name, :ios, DEPLOYMENT)

ext.build_configurations.each do |c|
  bs = c.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  bs['INFOPLIST_FILE'] = "#{target_name}/Info.plist"
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['CODE_SIGN_ENTITLEMENTS'] = "#{target_name}/#{target_name}.entitlements"
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['DEVELOPMENT_TEAM'] = TEAM
  bs['SWIFT_VERSION'] = '5.0'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SKIP_INSTALL'] = 'YES'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['MARKETING_VERSION'] = '1.0'
  bs['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../../Frameworks']
end

# File group for the extension's own files (path = folder of the same name).
group = project.main_group.find_subpath(target_name, true)
group.set_path(target_name)
swift_ref = group.new_reference("#{principal}.swift")
ext.add_file_references([swift_ref])
group.new_reference('Info.plist')
group.new_reference("#{target_name}.entitlements")

# Compile the Shared/* sources into the extension too.
shared_group = project.main_group.find_subpath('Shared') or abort 'Shared group not found (run 02_add_shared.rb first)'
shared_swift = shared_group.files.select { |f| f.display_name.end_with?('.swift') }
ext.add_file_references(shared_swift)

# App depends on the extension and embeds it.
app.add_dependency(ext)
embed = app.copy_files_build_phases.find { |p| p.display_name == 'Embed Foundation Extensions' }
unless embed
  embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.dst_path = ''
end
build_file = embed.add_file_reference(ext.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "Added extension target #{target_name} and embedded it in AntiDoom."
```

- [ ] **Step 2: Commit the script**

```bash
git add scripts/pbxproj/add_extension.rb
git commit -m "build: reusable xcodeproj script to add + embed app extensions"
```

---

## Task 6: DeviceActivityMonitor extension target

**Files:**
- Create: `DeviceActivityMonitor/DeviceActivityMonitorExtension.swift`
- Create: `DeviceActivityMonitor/Info.plist`
- Create: `DeviceActivityMonitor/DeviceActivityMonitor.entitlements`
- Modify: `AntiDoom.xcodeproj/project.pbxproj` (via script)

- [ ] **Step 1: Create the monitor skeleton**

Create `DeviceActivityMonitor/DeviceActivityMonitorExtension.swift`:

```swift
//  DeviceActivityMonitorExtension.swift
//  Skeleton DeviceActivity monitor. Real limit-handling logic is added in the
//  Blockier-Kern sub-project.

import DeviceActivity

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
    }
}
```

- [ ] **Step 2: Create the extension Info.plist**

Create `DeviceActivityMonitor/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>DeviceActivityMonitor</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.deviceactivity.monitor-extension</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
	</dict>
</dict>
</plist>
```

- [ ] **Step 3: Create the extension entitlements**

Create `DeviceActivityMonitor/DeviceActivityMonitor.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.family-controls</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.antidoom.AntiDoom</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Run the extension-adder script**

Run: `ruby scripts/pbxproj/add_extension.rb DeviceActivityMonitor antidoom.AntiDoom.DeviceActivityMonitor DeviceActivityMonitorExtension`
Expected: prints `Added extension target DeviceActivityMonitor and embedded it in AntiDoom.`

- [ ] **Step 5: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify the extension is embedded in the app**

Run: `find build -name 'AntiDoom.app' -path '*simulator*' -exec ls -1 {}/PlugIns \;`
Expected: output includes `DeviceActivityMonitor.appex`.

- [ ] **Step 7: Commit**

```bash
git add DeviceActivityMonitor AntiDoom.xcodeproj/project.pbxproj
git commit -m "feat: add DeviceActivityMonitor extension target"
```

---

## Task 7: ShieldConfiguration extension target

**Files:**
- Create: `ShieldConfiguration/ShieldConfigurationExtension.swift`
- Create: `ShieldConfiguration/Info.plist`
- Create: `ShieldConfiguration/ShieldConfiguration.entitlements`
- Modify: `AntiDoom.xcodeproj/project.pbxproj` (via script)

- [ ] **Step 1: Create the shield-configuration skeleton**

Create `ShieldConfiguration/ShieldConfigurationExtension.swift`:

```swift
//  ShieldConfigurationExtension.swift
//  Skeleton shield-configuration data source. The real reflection shield UI is
//  added in the Reflexions-Erlebnis sub-project.

import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
```

- [ ] **Step 2: Create the extension Info.plist**

Create `ShieldConfiguration/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>ShieldConfiguration</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.ManagedSettingsUI.shield-configuration-service</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension</string>
	</dict>
</dict>
</plist>
```

- [ ] **Step 3: Create the extension entitlements**

Create `ShieldConfiguration/ShieldConfiguration.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.family-controls</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.antidoom.AntiDoom</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: Run the extension-adder script**

Run: `ruby scripts/pbxproj/add_extension.rb ShieldConfiguration antidoom.AntiDoom.ShieldConfiguration ShieldConfigurationExtension`
Expected: prints `Added extension target ShieldConfiguration and embedded it in AntiDoom.`

- [ ] **Step 5: Verify the build succeeds**

Run: `./scripts/build-sim.sh`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify BOTH extensions are embedded**

Run: `find build -name 'AntiDoom.app' -path '*simulator*' -exec ls -1 {}/PlugIns \;`
Expected: output includes both `DeviceActivityMonitor.appex` and `ShieldConfiguration.appex`.

- [ ] **Step 7: Commit**

```bash
git add ShieldConfiguration AntiDoom.xcodeproj/project.pbxproj
git commit -m "feat: add ShieldConfiguration extension target"
```

---

## Task 8: Device-test handoff checklist

The foundation's real verification happens on the user's iPhone. Capture exactly what they must check.

**Files:**
- Create: `docs/superpowers/device-test-checklist-fundament.md`

- [ ] **Step 1: Write the checklist**

Create `docs/superpowers/device-test-checklist-fundament.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/device-test-checklist-fundament.md
git commit -m "docs: device-test checklist for foundation sub-project"
```

---

## Done criteria

- `./scripts/build-sim.sh` ends with `** BUILD SUCCEEDED **`
- The built `AntiDoom.app/PlugIns/` contains both `DeviceActivityMonitor.appex` and `ShieldConfiguration.appex`
- All three targets carry App Group + Family Controls entitlements
- The user has the device-test checklist to confirm on-device authorization and signing
