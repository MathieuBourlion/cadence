# Cadence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS floating panel app that lets photographers create and run automated camera control sequences via AppleScript to Capture One.

**Architecture:** SwiftUI views hosted in an NSPanel via NSHostingView. A stateless AppleScriptBridge builds and executes script strings. An @Observable SequenceRunner drives async execution with cancellation. Presets are JSON files in Application Support.

**Tech Stack:** Swift, SwiftUI, AppKit (NSPanel), NSAppleScript, Swift Concurrency, Codable/JSON

**Spec:** `docs/superpowers/specs/2026-03-21-cadence-design.md`

---

## File Map

| File | Responsibility |
|---|---|
| `Cadence/App/CadenceApp.swift` | @main entry point, NSApplicationDelegateAdaptor, panel creation |
| `Cadence/App/FloatingPanel.swift` | NSPanel subclass with floating level, vibrancy, size constraints |
| `Cadence/Models/SequenceStep.swift` | Step enum with associated values, Direction/Amount enums, Codable, isComplete |
| `Cadence/Models/CadenceSequence.swift` | Wraps [SequenceStep] + optional preset name, Codable |
| `Cadence/Engine/AppleScriptBridge.swift` | Static methods to build + execute AppleScript strings, AppleScriptError type |
| `Cadence/Engine/SequenceRunner.swift` | @Observable async runner: step iteration, delays, cancellation, error/toast state |
| `Cadence/Presets/PresetManager.swift` | Save/load/delete JSON preset files in Application Support |
| `Cadence/Views/ContentView.swift` | Main layout: header, scrollable step list, control bar |
| `Cadence/Views/StepCardView.swift` | Step card: collapsed summary, expanded inline editing, execution state borders |
| `Cadence/Views/AddStepPopover.swift` | Popover listing 8 step types with descriptions |
| `Cadence/Views/ControlBar.swift` | Run/Stop/Reset buttons with state-driven visibility |
| `Cadence/Views/PresetsPopover.swift` | Preset list popover with load + context menu delete |
| `Cadence/Views/SavePresetSheet.swift` | Sheet with name text field for saving presets |
| `Cadence/Views/ToastView.swift` | Non-blocking warning toast overlay |
| `CadenceTests/SequenceStepTests.swift` | Tests for step model, Codable, isComplete |
| `CadenceTests/CadenceSequenceTests.swift` | Tests for sequence serialization, preset format |
| `CadenceTests/AppleScriptBridgeTests.swift` | Tests for script string building (not execution) |
| `CadenceTests/PresetManagerTests.swift` | Tests for file save/load/delete |
| `CadenceTests/SequenceRunnerTests.swift` | Tests for runner state transitions, cancellation |

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `project.yml` (XcodeGen spec)
- Create: `Cadence/App/CadenceApp.swift` (minimal placeholder)
- Create: `Cadence/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `Cadence/Info.plist`

- [ ] **Step 1: Install XcodeGen if needed**

Run: `which xcodegen || brew install xcodegen`

- [ ] **Step 2: Create project.yml**

```yaml
name: Cadence
options:
  bundleIdPrefix: com.cadence
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
  createIntermediateGroups: true

targets:
  Cadence:
    type: application
    platform: macOS
    sources:
      - path: Cadence
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.cadence.app
        PRODUCT_NAME: Cadence
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: 1
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        INFOPLIST_FILE: Cadence/Info.plist
        SWIFT_VERSION: "5.9"
    info:
      path: Cadence/Info.plist
      properties:
        CFBundleName: Cadence
        CFBundleDisplayName: Cadence
        CFBundleIdentifier: com.cadence.app
        CFBundleVersion: "1"
        CFBundleShortVersionString: "1.0.0"
        CFBundlePackageType: APPL
        CFBundleExecutable: Cadence
        LSMinimumSystemVersion: "13.0"
        NSAppleEventsUsageDescription: "Cadence needs to communicate with Capture One to control cameras and execute sequences."

  CadenceTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: CadenceTests
    dependencies:
      - target: Cadence
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.cadence.tests
        SWIFT_VERSION: "5.9"
```

- [ ] **Step 3: Create minimal CadenceApp.swift**

```swift
import SwiftUI

@main
struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Cadence")
        }
    }
}
```

- [ ] **Step 4: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Cadence</string>
    <key>CFBundleDisplayName</key>
    <string>Cadence</string>
    <key>CFBundleIdentifier</key>
    <string>com.cadence.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Cadence</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Cadence needs to communicate with Capture One to control cameras and execute sequences.</string>
</dict>
</plist>
```

- [ ] **Step 5: Create AccentColor asset (Capture One amber/orange)**

Create `Cadence/Assets.xcassets/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Create `Cadence/Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.937",
          "green" : "0.569",
          "blue" : "0.129",
          "alpha" : "1.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 6: Create empty test placeholder**

Create `CadenceTests/CadenceTests.swift`:
```swift
import XCTest

final class CadenceTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 7: Generate Xcode project and verify build**

Run: `cd /path/to/cadence && xcodegen generate`
Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add project.yml Cadence/ CadenceTests/ Cadence.xcodeproj/
git commit -m "feat: scaffold Xcode project with XcodeGen"
```

---

## Task 2: Data Model — SequenceStep

**Files:**
- Create: `Cadence/Models/SequenceStep.swift`
- Create: `CadenceTests/SequenceStepTests.swift`

- [ ] **Step 1: Write failing tests for SequenceStep**

```swift
import XCTest
@testable import Cadence

final class SequenceStepTests: XCTestCase {

    // MARK: - isComplete

    func testCaptureIsAlwaysComplete() {
        let step = SequenceStep.capture(postCaptureDelay: 3)
        XCTAssertTrue(step.isComplete)
    }

    func testSwitchCameraIsIncompleteWhenNil() {
        let step = SequenceStep.switchCamera(cameraName: nil)
        XCTAssertFalse(step.isComplete)
    }

    func testSwitchCameraIsCompleteWhenSet() {
        let step = SequenceStep.switchCamera(cameraName: "Canon EOS R5")
        XCTAssertTrue(step.isComplete)
    }

    func testSetISOIsAlwaysComplete() {
        let step = SequenceStep.setISO(value: "400")
        XCTAssertTrue(step.isComplete)
    }

    func testAutofocusIsAlwaysComplete() {
        let step = SequenceStep.autofocus
        XCTAssertTrue(step.isComplete)
    }

    func testMoveFocusIsAlwaysComplete() {
        let step = SequenceStep.moveFocus(direction: .nearer, amount: .medium)
        XCTAssertTrue(step.isComplete)
    }

    func testWaitIsAlwaysComplete() {
        let step = SequenceStep.wait(seconds: 5)
        XCTAssertTrue(step.isComplete)
    }

    // MARK: - Codable round-trip

    func testCaptureEncodeDecode() throws {
        let step = SequenceStep.capture(postCaptureDelay: 5)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(step, decoded)
    }

    func testSwitchCameraEncodeDecodeWithNil() throws {
        let step = SequenceStep.switchCamera(cameraName: nil)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(step, decoded)
    }

    func testSetISOEncodeDecode() throws {
        let step = SequenceStep.setISO(value: "1600")
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(step, decoded)
    }

    func testMoveFocusEncodeDecode() throws {
        let step = SequenceStep.moveFocus(direction: .further, amount: .large)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(step, decoded)
    }

    func testWaitEncodeDecode() throws {
        let step = SequenceStep.wait(seconds: 10)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: data)
        XCTAssertEqual(step, decoded)
    }

    // MARK: - JSON format matches spec

    func testCaptureJSONFormat() throws {
        let step = SequenceStep.capture(postCaptureDelay: 3)
        let data = try JSONEncoder().encode(step)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "capture")
        let config = json["config"] as! [String: Any]
        XCTAssertEqual(config["postCaptureDelay"] as? Int, 3)
    }

    func testSwitchCameraJSONFormatWhenNil() throws {
        let step = SequenceStep.switchCamera(cameraName: nil)
        let data = try JSONEncoder().encode(step)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "switchCamera")
        let config = json["config"] as! [String: Any]
        XCTAssertTrue(config.isEmpty)
    }

    // MARK: - Display properties

    func testTypeName() {
        XCTAssertEqual(SequenceStep.capture(postCaptureDelay: 3).typeName, "Capture")
        XCTAssertEqual(SequenceStep.switchCamera(cameraName: nil).typeName, "Switch Camera")
        XCTAssertEqual(SequenceStep.setISO(value: "400").typeName, "Set ISO")
        XCTAssertEqual(SequenceStep.setAperture(value: "f/5.6").typeName, "Set Aperture")
        XCTAssertEqual(SequenceStep.setShutterSpeed(value: "1/125").typeName, "Set Shutter Speed")
        XCTAssertEqual(SequenceStep.autofocus.typeName, "Autofocus")
        XCTAssertEqual(SequenceStep.moveFocus(direction: .nearer, amount: .medium).typeName, "Move Focus")
        XCTAssertEqual(SequenceStep.wait(seconds: 5).typeName, "Wait")
    }

    func testConfigSummary() {
        XCTAssertEqual(
            SequenceStep.capture(postCaptureDelay: 5).configSummary,
            "Post-capture delay: 5s"
        )
        XCTAssertEqual(
            SequenceStep.switchCamera(cameraName: "Canon EOS R5").configSummary,
            "Canon EOS R5"
        )
        XCTAssertEqual(
            SequenceStep.switchCamera(cameraName: nil).configSummary,
            "No camera selected"
        )
        XCTAssertEqual(
            SequenceStep.setISO(value: "800").configSummary,
            "ISO 800"
        )
        XCTAssertEqual(
            SequenceStep.moveFocus(direction: .further, amount: .large).configSummary,
            "Further, Large"
        )
        XCTAssertEqual(
            SequenceStep.wait(seconds: 10).configSummary,
            "10 seconds"
        )
    }

    // MARK: - MoveFocus amount mapping

    func testMoveFocusAmountValue() {
        XCTAssertEqual(FocusAmount.small.value, 1)
        XCTAssertEqual(FocusAmount.medium.value, 3)
        XCTAssertEqual(FocusAmount.large.value, 7)
    }

    func testMoveFocusSignedAmount() {
        // Nearer = negative, Further = positive
        let nearerMedium = SequenceStep.moveFocus(direction: .nearer, amount: .medium)
        XCTAssertEqual(nearerMedium.focusAmountSigned, -3)

        let furtherLarge = SequenceStep.moveFocus(direction: .further, amount: .large)
        XCTAssertEqual(furtherLarge.focusAmountSigned, 7)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: FAIL — SequenceStep not defined

- [ ] **Step 3: Implement SequenceStep**

```swift
import Foundation

enum FocusDirection: String, Codable, CaseIterable {
    case nearer
    case further
}

enum FocusAmount: String, Codable, CaseIterable {
    case small
    case medium
    case large

    var value: Int {
        switch self {
        case .small: 1
        case .medium: 3
        case .large: 7
        }
    }
}

enum SequenceStep: Equatable {
    case capture(postCaptureDelay: Int)
    case switchCamera(cameraName: String?)
    case setISO(value: String)
    case setAperture(value: String)
    case setShutterSpeed(value: String)
    case autofocus
    case moveFocus(direction: FocusDirection, amount: FocusAmount)
    case wait(seconds: Int)

    // Note: SequenceStep does NOT conform to Identifiable.
    // Use IdentifiableStep wrapper (see Task 8) for SwiftUI identity.

    var isComplete: Bool {
        switch self {
        case .switchCamera(let name): name != nil
        default: true
        }
    }

    var typeName: String {
        switch self {
        case .capture: "Capture"
        case .switchCamera: "Switch Camera"
        case .setISO: "Set ISO"
        case .setAperture: "Set Aperture"
        case .setShutterSpeed: "Set Shutter Speed"
        case .autofocus: "Autofocus"
        case .moveFocus: "Move Focus"
        case .wait: "Wait"
        }
    }

    var configSummary: String {
        switch self {
        case .capture(let delay): "Post-capture delay: \(delay)s"
        case .switchCamera(let name): name ?? "No camera selected"
        case .setISO(let value): "ISO \(value)"
        case .setAperture(let value): value
        case .setShutterSpeed(let value): value
        case .autofocus: "Triggers autofocus then waits 1 second"
        case .moveFocus(let dir, let amt): "\(dir.rawValue.capitalized), \(amt.rawValue.capitalized)"
        case .wait(let seconds): "\(seconds) seconds"
        }
    }

    var focusAmountSigned: Int? {
        guard case .moveFocus(let direction, let amount) = self else { return nil }
        return direction == .nearer ? -amount.value : amount.value
    }

    // MARK: - Static picker values

    static let isoValues = ["100", "125", "160", "200", "250", "320", "400", "500", "640", "800", "1000", "1250", "1600", "2000", "2500", "3200", "6400", "12800", "25600"]

    static let apertureValues = ["f/1.4", "f/1.8", "f/2", "f/2.8", "f/3.5", "f/4", "f/5.6", "f/6.3", "f/7.1", "f/8", "f/11", "f/13", "f/16", "f/18", "f/22"]

    static let shutterSpeedValues = ["1/4000", "1/2000", "1/1000", "1/500", "1/250", "1/125", "1/60", "1/30", "1/15", "1/8", "1/4", "1/2", "1\"", "2\"", "4\"", "8\"", "15\"", "30\""]
}

// MARK: - Codable

extension SequenceStep: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case config
    }

    private enum StepType: String, Codable {
        case capture, switchCamera, setISO, setAperture, setShutterSpeed
        case autofocus, moveFocus, wait
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .capture(let delay):
            try container.encode(StepType.capture, forKey: .type)
            try container.encode(["postCaptureDelay": delay], forKey: .config)
        case .switchCamera(let name):
            try container.encode(StepType.switchCamera, forKey: .type)
            if let name {
                try container.encode(["cameraName": name], forKey: .config)
            } else {
                try container.encode([String: String](), forKey: .config)
            }
        case .setISO(let value):
            try container.encode(StepType.setISO, forKey: .type)
            try container.encode(["value": value], forKey: .config)
        case .setAperture(let value):
            try container.encode(StepType.setAperture, forKey: .type)
            try container.encode(["value": value], forKey: .config)
        case .setShutterSpeed(let value):
            try container.encode(StepType.setShutterSpeed, forKey: .type)
            try container.encode(["value": value], forKey: .config)
        case .autofocus:
            try container.encode(StepType.autofocus, forKey: .type)
            try container.encode([String: String](), forKey: .config)
        case .moveFocus(let direction, let amount):
            try container.encode(StepType.moveFocus, forKey: .type)
            try container.encode(["direction": direction.rawValue, "amount": amount.rawValue], forKey: .config)
        case .wait(let seconds):
            try container.encode(StepType.wait, forKey: .type)
            try container.encode(["seconds": seconds], forKey: .config)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StepType.self, forKey: .type)
        switch type {
        case .capture:
            let config = try container.decode([String: Int].self, forKey: .config)
            self = .capture(postCaptureDelay: config["postCaptureDelay"] ?? 3)
        case .switchCamera:
            let config = try container.decode([String: String].self, forKey: .config)
            self = .switchCamera(cameraName: config["cameraName"])
        case .setISO:
            let config = try container.decode([String: String].self, forKey: .config)
            self = .setISO(value: config["value"] ?? "400")
        case .setAperture:
            let config = try container.decode([String: String].self, forKey: .config)
            self = .setAperture(value: config["value"] ?? "f/5.6")
        case .setShutterSpeed:
            let config = try container.decode([String: String].self, forKey: .config)
            self = .setShutterSpeed(value: config["value"] ?? "1/125")
        case .autofocus:
            self = .autofocus
        case .moveFocus:
            let config = try container.decode([String: String].self, forKey: .config)
            let direction = FocusDirection(rawValue: config["direction"] ?? "nearer") ?? .nearer
            let amount = FocusAmount(rawValue: config["amount"] ?? "medium") ?? .medium
            self = .moveFocus(direction: direction, amount: amount)
        case .wait:
            let config = try container.decode([String: Int].self, forKey: .config)
            self = .wait(seconds: config["seconds"] ?? 5)
        }
    }
}
```

Note: The `id` property regenerates each access — this is intentional for the enum. The view layer will wrap steps in an `IdentifiableStep` struct (Task 8) that holds a stable UUID.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: All SequenceStepTests PASS

- [ ] **Step 5: Commit**

```bash
git add Cadence/Models/SequenceStep.swift CadenceTests/SequenceStepTests.swift
git commit -m "feat: add SequenceStep model with Codable and display properties"
```

---

## Task 3: Data Model — CadenceSequence

**Files:**
- Create: `Cadence/Models/CadenceSequence.swift`
- Create: `CadenceTests/CadenceSequenceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import Cadence

final class CadenceSequenceTests: XCTestCase {

    func testEmptySequenceEncodeDecode() throws {
        let seq = CadenceSequence(name: nil, steps: [])
        let data = try JSONEncoder().encode(seq)
        let decoded = try JSONDecoder().decode(CadenceSequence.self, from: data)
        XCTAssertNil(decoded.name)
        XCTAssertTrue(decoded.steps.isEmpty)
    }

    func testSequenceWithStepsEncodeDecode() throws {
        let steps: [SequenceStep] = [
            .capture(postCaptureDelay: 3),
            .setISO(value: "400"),
            .switchCamera(cameraName: nil),
            .wait(seconds: 5)
        ]
        let seq = CadenceSequence(name: "Test Preset", steps: steps)
        let data = try JSONEncoder().encode(seq)
        let decoded = try JSONDecoder().decode(CadenceSequence.self, from: data)
        XCTAssertEqual(decoded.name, "Test Preset")
        XCTAssertEqual(decoded.steps.count, 4)
        XCTAssertEqual(decoded.steps[0], .capture(postCaptureDelay: 3))
        XCTAssertEqual(decoded.steps[2], .switchCamera(cameraName: nil))
    }

    func testAllStepsComplete() {
        let complete = CadenceSequence(name: nil, steps: [
            .capture(postCaptureDelay: 3),
            .setISO(value: "400")
        ])
        XCTAssertTrue(complete.allStepsComplete)

        let incomplete = CadenceSequence(name: nil, steps: [
            .capture(postCaptureDelay: 3),
            .switchCamera(cameraName: nil)
        ])
        XCTAssertFalse(incomplete.allStepsComplete)
    }

    func testCanRun() {
        let empty = CadenceSequence(name: nil, steps: [])
        XCTAssertFalse(empty.canRun)

        let incomplete = CadenceSequence(name: nil, steps: [.switchCamera(cameraName: nil)])
        XCTAssertFalse(incomplete.canRun)

        let ready = CadenceSequence(name: nil, steps: [.capture(postCaptureDelay: 3)])
        XCTAssertTrue(ready.canRun)
    }

    func testSwitchCameraStrippedForPreset() throws {
        let steps: [SequenceStep] = [
            .capture(postCaptureDelay: 3),
            .switchCamera(cameraName: "Canon EOS R5")
        ]
        let seq = CadenceSequence(name: "Test", steps: steps)
        let forPreset = seq.strippedForPreset()
        XCTAssertEqual(forPreset.steps[1], .switchCamera(cameraName: nil))
        XCTAssertEqual(forPreset.steps[0], .capture(postCaptureDelay: 3))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: FAIL — CadenceSequence not defined

- [ ] **Step 3: Implement CadenceSequence**

```swift
import Foundation

struct CadenceSequence: Codable, Equatable {
    var name: String?
    var steps: [SequenceStep]

    var allStepsComplete: Bool {
        steps.allSatisfy(\.isComplete)
    }

    var canRun: Bool {
        !steps.isEmpty && allStepsComplete
    }

    /// Returns a copy with Switch Camera steps stripped of camera names (for preset saving).
    func strippedForPreset() -> CadenceSequence {
        var copy = self
        copy.steps = steps.map { step in
            if case .switchCamera = step {
                return .switchCamera(cameraName: nil)
            }
            return step
        }
        return copy
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: All CadenceSequenceTests PASS

- [ ] **Step 5: Commit**

```bash
git add Cadence/Models/CadenceSequence.swift CadenceTests/CadenceSequenceTests.swift
git commit -m "feat: add CadenceSequence model with preset stripping"
```

---

## Task 4: AppleScriptBridge — Script Building

**Files:**
- Create: `Cadence/Engine/AppleScriptBridge.swift`
- Create: `CadenceTests/AppleScriptBridgeTests.swift`

- [ ] **Step 1: Write failing tests for script string building**

These test the string building only, not execution (which requires Capture One).

```swift
import XCTest
@testable import Cadence

final class AppleScriptBridgeTests: XCTestCase {

    func testCaptureScript() {
        let script = AppleScriptBridge.scriptForStep(.capture(postCaptureDelay: 3))
        XCTAssertEqual(script, "tell application \"Capture One\" to capture")
    }

    func testSwitchCameraScript() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(cameraName: "Canon EOS R5"))
        XCTAssertEqual(script, "tell application \"Capture One\" to select camera of front document name \"Canon EOS R5\"")
    }

    func testSetISOScript() {
        let script = AppleScriptBridge.scriptForStep(.setISO(value: "800"))
        XCTAssertEqual(script, "set ISO of camera of front document of application \"Capture One\" to \"800\"")
    }

    func testSetApertureScript() {
        let script = AppleScriptBridge.scriptForStep(.setAperture(value: "f/5.6"))
        XCTAssertEqual(script, "set aperture of camera of front document of application \"Capture One\" to \"f/5.6\"")
    }

    func testSetShutterSpeedScript() {
        let script = AppleScriptBridge.scriptForStep(.setShutterSpeed(value: "1/125"))
        XCTAssertEqual(script, "set shutter speed of camera of front document of application \"Capture One\" to \"1/125\"")
    }

    func testSetShutterSpeedWithQuotes() {
        // Values like 1" contain double quotes that must be escaped in AppleScript
        let script = AppleScriptBridge.scriptForStep(.setShutterSpeed(value: "1\""))
        XCTAssertTrue(script.contains("1\\\"") || script.contains("1\" & quote"))
        // The exact escaping strategy is implementation-defined, but the script must be valid
    }

    func testAutofocusScript() {
        let script = AppleScriptBridge.scriptForStep(.autofocus)
        XCTAssertEqual(script, "set autofocusing of camera of front document of application \"Capture One\" to true")
    }

    func testMoveFocusScript() {
        let script = AppleScriptBridge.scriptForStep(.moveFocus(direction: .nearer, amount: .medium))
        XCTAssertEqual(script, "tell application \"Capture One\" to adjust focus of camera of front document by amount -3 sync true")
    }

    func testMoveFocusFurtherLarge() {
        let script = AppleScriptBridge.scriptForStep(.moveFocus(direction: .further, amount: .large))
        XCTAssertEqual(script, "tell application \"Capture One\" to adjust focus of camera of front document by amount 7 sync true")
    }

    func testWaitReturnsNil() {
        let script = AppleScriptBridge.scriptForStep(.wait(seconds: 5))
        XCTAssertNil(script, "Wait steps use Task.sleep, not AppleScript")
    }

    func testPingScript() {
        let script = AppleScriptBridge.pingScript
        XCTAssertEqual(script, "name of application \"Capture One\"")
    }

    func testCameraListScript() {
        let script = AppleScriptBridge.cameraListScript
        XCTAssertEqual(script, "available camera identifiers of front document of application \"Capture One\"")
    }

    func testReadBackISOScript() {
        let script = AppleScriptBridge.readBackScript(for: .setISO(value: "400"))
        XCTAssertEqual(script, "ISO of camera of front document of application \"Capture One\"")
    }

    func testReadBackApertureScript() {
        let script = AppleScriptBridge.readBackScript(for: .setAperture(value: "f/5.6"))
        XCTAssertEqual(script, "aperture of camera of front document of application \"Capture One\"")
    }

    func testReadBackShutterScript() {
        let script = AppleScriptBridge.readBackScript(for: .setShutterSpeed(value: "1/125"))
        XCTAssertEqual(script, "shutter speed of camera of front document of application \"Capture One\"")
    }

    func testReadBackReturnsNilForNonSettingsSteps() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .capture(postCaptureDelay: 3)))
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .autofocus))
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .wait(seconds: 5)))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: FAIL — AppleScriptBridge not defined

- [ ] **Step 3: Implement AppleScriptBridge**

```swift
import Foundation

struct AppleScriptError: Error, LocalizedError {
    let message: String
    let errorNumber: Int?

    var errorDescription: String? { message }

    init(from errorInfo: NSDictionary?) {
        self.message = errorInfo?[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
        self.errorNumber = errorInfo?[NSAppleScript.errorNumber] as? Int
    }
}

struct AppleScriptBridge {

    static let pingScript = "name of application \"Capture One\""
    static let cameraListScript = "available camera identifiers of front document of application \"Capture One\""

    // MARK: - Script building

    /// Returns the AppleScript string for a step, or nil if the step doesn't use AppleScript (Wait).
    static func scriptForStep(_ step: SequenceStep) -> String? {
        switch step {
        case .capture:
            return "tell application \"Capture One\" to capture"
        case .switchCamera(let name):
            guard let name else { return nil }
            return "tell application \"Capture One\" to select camera of front document name \"\(name)\""
        case .setISO(let value):
            return "set ISO of camera of front document of application \"Capture One\" to \"\(value)\""
        case .setAperture(let value):
            return "set aperture of camera of front document of application \"Capture One\" to \"\(value)\""
        case .setShutterSpeed(let value):
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "set shutter speed of camera of front document of application \"Capture One\" to \"\(escaped)\""
        case .autofocus:
            return "set autofocusing of camera of front document of application \"Capture One\" to true"
        case .moveFocus(let direction, let amount):
            let signed = direction == .nearer ? -amount.value : amount.value
            return "tell application \"Capture One\" to adjust focus of camera of front document by amount \(signed) sync true"
        case .wait:
            return nil
        }
    }

    /// Returns the read-back script for camera settings steps, or nil for other steps.
    static func readBackScript(for step: SequenceStep) -> String? {
        switch step {
        case .setISO: "ISO of camera of front document of application \"Capture One\""
        case .setAperture: "aperture of camera of front document of application \"Capture One\""
        case .setShutterSpeed: "shutter speed of camera of front document of application \"Capture One\""
        default: nil
        }
    }

    // MARK: - Execution

    @discardableResult
    static func execute(_ script: String) -> Result<String?, AppleScriptError> {
        var errorInfo: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return .failure(AppleScriptError(from: errorInfo))
        }
        return .success(result?.stringValue)
    }

    static func executeForList(_ script: String) -> Result<[String], AppleScriptError> {
        var errorInfo: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            return .failure(AppleScriptError(from: errorInfo))
        }
        guard let descriptor = result else { return .success([]) }
        var items: [String] = []
        let count = descriptor.numberOfItems
        guard count > 0 else { return .success([]) }
        // NSAppleEventDescriptor lists are 1-indexed
        for i in 1...count {
            if let item = descriptor.atIndex(i)?.stringValue {
                items.append(item)
            }
        }
        return .success(items)
    }

    static func ping() -> Bool {
        if case .success = execute(pingScript) { return true }
        return false
    }

    static func fetchCameraList() -> Result<[String], AppleScriptError> {
        executeForList(cameraListScript)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: All AppleScriptBridgeTests PASS

Note: The shutter speed quote escaping test may need adjustment depending on the exact escaping strategy. Update the test assertion to match the implementation.

- [ ] **Step 5: Commit**

```bash
git add Cadence/Engine/AppleScriptBridge.swift CadenceTests/AppleScriptBridgeTests.swift
git commit -m "feat: add AppleScriptBridge with script building and execution"
```

---

## Task 5: PresetManager

**Files:**
- Create: `Cadence/Presets/PresetManager.swift`
- Create: `CadenceTests/PresetManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import Cadence

final class PresetManagerTests: XCTestCase {
    var testDir: URL!
    var manager: PresetManager!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CadenceTests-\(UUID().uuidString)")
        manager = PresetManager(directory: testDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let seq = CadenceSequence(name: "Test", steps: [
            .capture(postCaptureDelay: 3),
            .setISO(value: "400")
        ])
        try manager.save(seq, name: "Test")
        let loaded = try manager.load(name: "Test")
        XCTAssertEqual(loaded.name, "Test")
        XCTAssertEqual(loaded.steps.count, 2)
        XCTAssertEqual(loaded.steps[0], .capture(postCaptureDelay: 3))
    }

    func testSaveStripsCamera() throws {
        let seq = CadenceSequence(name: "Test", steps: [
            .switchCamera(cameraName: "Canon EOS R5")
        ])
        try manager.save(seq, name: "Test")
        let loaded = try manager.load(name: "Test")
        XCTAssertEqual(loaded.steps[0], .switchCamera(cameraName: nil))
    }

    func testListPresets() throws {
        let seq = CadenceSequence(name: nil, steps: [.wait(seconds: 1)])
        try manager.save(seq, name: "Alpha")
        try manager.save(seq, name: "Beta")
        let names = try manager.listPresets()
        XCTAssertTrue(names.contains("Alpha"))
        XCTAssertTrue(names.contains("Beta"))
        XCTAssertEqual(names.count, 2)
    }

    func testDelete() throws {
        let seq = CadenceSequence(name: nil, steps: [.wait(seconds: 1)])
        try manager.save(seq, name: "ToDelete")
        XCTAssertTrue(try manager.listPresets().contains("ToDelete"))
        try manager.delete(name: "ToDelete")
        XCTAssertFalse(try manager.listPresets().contains("ToDelete"))
    }

    func testLoadNonexistent() {
        XCTAssertThrowsError(try manager.load(name: "NoSuchPreset"))
    }

    func testOverwrite() throws {
        let seq1 = CadenceSequence(name: "V1", steps: [.wait(seconds: 1)])
        let seq2 = CadenceSequence(name: "V2", steps: [.wait(seconds: 10)])
        try manager.save(seq1, name: "Overwrite")
        try manager.save(seq2, name: "Overwrite")
        let loaded = try manager.load(name: "Overwrite")
        XCTAssertEqual(loaded.name, "V2")
    }

    func testPresetExists() throws {
        let seq = CadenceSequence(name: nil, steps: [.wait(seconds: 1)])
        XCTAssertFalse(manager.presetExists(name: "Foo"))
        try manager.save(seq, name: "Foo")
        XCTAssertTrue(manager.presetExists(name: "Foo"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: FAIL — PresetManager not defined

- [ ] **Step 3: Implement PresetManager**

```swift
import Foundation

struct PresetManager {
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = appSupport.appendingPathComponent("Cadence/presets")
        }
    }

    func save(_ sequence: CadenceSequence, name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stripped = sequence.strippedForPreset()
        var toSave = stripped
        toSave.name = name
        let data = try JSONEncoder().encode(toSave)
        let url = directory.appendingPathComponent("\(name).json")
        try data.write(to: url)
    }

    func load(name: String) throws -> CadenceSequence {
        let url = directory.appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CadenceSequence.self, from: data)
    }

    func delete(name: String) throws {
        let url = directory.appendingPathComponent("\(name).json")
        try FileManager.default.removeItem(at: url)
    }

    func listPresets() throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    func presetExists(name: String) -> Bool {
        let url = directory.appendingPathComponent("\(name).json")
        return FileManager.default.fileExists(atPath: url.path)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: All PresetManagerTests PASS

- [ ] **Step 5: Commit**

```bash
git add Cadence/Presets/PresetManager.swift CadenceTests/PresetManagerTests.swift
git commit -m "feat: add PresetManager for JSON preset save/load/delete"
```

---

## Task 6: SequenceRunner

**Files:**
- Create: `Cadence/Engine/SequenceRunner.swift`
- Create: `CadenceTests/SequenceRunnerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import Cadence

final class SequenceRunnerTests: XCTestCase {

    func testInitialState() {
        let runner = SequenceRunner()
        XCTAssertFalse(runner.isRunning)
        XCTAssertNil(runner.currentStepIndex)
        XCTAssertNil(runner.error)
    }

    func testPostStepDelayForCapture() {
        let delay = SequenceRunner.postStepDelay(for: .capture(postCaptureDelay: 5))
        XCTAssertEqual(delay, 5.0)
    }

    func testPostStepDelayForCaptureMinimum() {
        // Even if somehow set below 3, enforce minimum
        let delay = SequenceRunner.postStepDelay(for: .capture(postCaptureDelay: 1))
        XCTAssertEqual(delay, 3.0)
    }

    func testPostStepDelayForAutofocus() {
        let delay = SequenceRunner.postStepDelay(for: .autofocus)
        XCTAssertEqual(delay, 1.0)
    }

    func testPostStepDelayForMoveFocus() {
        let delay = SequenceRunner.postStepDelay(for: .moveFocus(direction: .nearer, amount: .small))
        XCTAssertEqual(delay, 0.8)
    }

    func testPostStepDelayForWait() {
        let delay = SequenceRunner.postStepDelay(for: .wait(seconds: 10))
        XCTAssertEqual(delay, 10.0)
    }

    func testPostStepDelayForSetISO() {
        let delay = SequenceRunner.postStepDelay(for: .setISO(value: "400"))
        XCTAssertEqual(delay, 0.0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: FAIL — SequenceRunner not defined

- [ ] **Step 3: Implement SequenceRunner**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class SequenceRunner {
    var isRunning = false
    var currentStepIndex: Int?
    var error: AppleScriptError?
    var toastMessage: String?

    private var runTask: Task<Void, Never>?

    /// Calculates the delay in seconds after executing a step.
    static func postStepDelay(for step: SequenceStep) -> TimeInterval {
        switch step {
        case .capture(let delay):
            return TimeInterval(max(delay, 3))
        case .autofocus:
            return 1.0
        case .moveFocus:
            return 0.8
        case .wait(let seconds):
            return TimeInterval(seconds)
        default:
            return 0.0
        }
    }

    func run(steps: [SequenceStep]) {
        guard !isRunning else { return }

        // Pre-flight: check Capture One is running
        guard AppleScriptBridge.ping() else {
            error = AppleScriptError(
                from: ["NSAppleScriptErrorMessage": "Capture One is not running. Open Capture One and try again."] as NSDictionary
            )
            return
        }

        // Pre-flight: check all steps complete
        guard steps.allSatisfy(\.isComplete) else {
            error = AppleScriptError(
                from: ["NSAppleScriptErrorMessage": "Complete all steps before running."] as NSDictionary
            )
            return
        }

        isRunning = true
        error = nil
        currentStepIndex = nil

        runTask = Task {
            for (index, step) in steps.enumerated() {
                // Check cancellation before each step
                if Task.isCancelled { break }

                currentStepIndex = index

                // Execute the step's AppleScript (if any)
                if let script = AppleScriptBridge.scriptForStep(step) {
                    let result = AppleScriptBridge.execute(script)
                    if case .failure(let scriptError) = result {
                        error = scriptError
                        break
                    }

                    // Read-back verification for camera settings
                    if let readBackScript = AppleScriptBridge.readBackScript(for: step) {
                        let readBackResult = AppleScriptBridge.execute(readBackScript)
                        if case .success(let actualValue) = readBackResult,
                           let actual = actualValue {
                            let requested = requestedValue(for: step)
                            if let requested, actual != requested {
                                let settingName = step.typeName.replacingOccurrences(of: "Set ", with: "")
                                toastMessage = "Could not set \(settingName) to \(requested). Camera is using \(actual)."
                                // Auto-dismiss toast after 4 seconds
                                Task {
                                    try? await Task.sleep(for: .seconds(4))
                                    if !Task.isCancelled { toastMessage = nil }
                                }
                            }
                        }
                    }
                }

                // Post-step delay
                let delay = Self.postStepDelay(for: step)
                if delay > 0 {
                    do {
                        try await Task.sleep(for: .seconds(delay))
                    } catch {
                        break // Cancelled
                    }
                }
            }

            isRunning = false
            currentStepIndex = nil
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        currentStepIndex = nil
    }

    private func requestedValue(for step: SequenceStep) -> String? {
        switch step {
        case .setISO(let value): value
        case .setAperture(let value): value
        case .setShutterSpeed(let value): value
        default: nil
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: All SequenceRunnerTests PASS

- [ ] **Step 5: Commit**

```bash
git add Cadence/Engine/SequenceRunner.swift CadenceTests/SequenceRunnerTests.swift
git commit -m "feat: add SequenceRunner with async execution, cancellation, and read-back verification"
```

---

## Task 7: Floating Panel

**Files:**
- Create: `Cadence/App/FloatingPanel.swift`
- Modify: `Cadence/App/CadenceApp.swift`

No tests for this task — it's pure AppKit window setup that can only be verified by building and running.

- [ ] **Step 1: Implement FloatingPanel**

```swift
import AppKit
import SwiftUI

class FloatingPanel: NSPanel {

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Floating above other windows
        level = .floating
        isFloatingPanel = true

        // Size constraints
        minSize = NSSize(width: 380, height: 500)
        maxSize = NSSize(width: 380, height: .greatestFiniteMagnitude)

        // No fullscreen
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Vibrancy background
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active

        // Host SwiftUI content
        let hostingView = NSHostingView(rootView:
            contentView
                .preferredColorScheme(.dark)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        contentView = visualEffect
        titlebarAppearsTransparent = true
        title = "Cadence"

        // Center on screen on first launch
        center()
    }
}
```

- [ ] **Step 2: Update CadenceApp to use FloatingPanel**

Replace the placeholder `CadenceApp.swift` with:

```swift
import SwiftUI
import AppKit

@main
struct CadenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty — window is managed by AppDelegate via FloatingPanel
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
        panel = FloatingPanel(contentView: contentView)
        panel?.orderFrontRegardless()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
```

- [ ] **Step 3: Create a stub ContentView**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Cadence")
                .font(.headline)
                .fontWeight(.medium)
            Spacer()
            Text("Steps will appear here")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

Optionally run the app to verify the floating panel appears with dark vibrancy.

- [ ] **Step 5: Commit**

```bash
git add Cadence/App/FloatingPanel.swift Cadence/App/CadenceApp.swift Cadence/Views/ContentView.swift
git commit -m "feat: add floating panel with dark vibrancy and SwiftUI hosting"
```

---

## Task 8: ContentView — Main Layout

**Files:**
- Modify: `Cadence/Views/ContentView.swift`

- [ ] **Step 1: Create IdentifiableStep wrapper**

Add to `Cadence/Models/SequenceStep.swift`:

```swift
struct IdentifiableStep: Identifiable, Equatable {
    let id: UUID
    var step: SequenceStep

    init(step: SequenceStep, id: UUID = UUID()) {
        self.id = id
        self.step = step
    }

    static func == (lhs: IdentifiableStep, rhs: IdentifiableStep) -> Bool {
        lhs.id == rhs.id && lhs.step == rhs.step
    }
}
```

- [ ] **Step 2: Implement ContentView with full layout**

```swift
import SwiftUI

struct ContentView: View {
    @State private var steps: [IdentifiableStep] = []
    @State private var expandedStepID: UUID?
    @State private var showAddStepPopover = false
    @State private var showPresetsPopover = false
    @State private var showSavePresetSheet = false
    @State private var showResetConfirmation = false

    @State private var runner = SequenceRunner()
    private let presetManager = PresetManager()

    private var canRun: Bool {
        !steps.isEmpty && steps.allSatisfy(\.step.isComplete)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cadence")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: { showSavePresetSheet = true }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(steps.isEmpty)

                Button(action: { showPresetsPopover.toggle() }) {
                    Image(systemName: "list.bullet")
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showPresetsPopover) {
                    PresetsPopover(presetManager: presetManager, hasExistingSteps: !steps.isEmpty) { sequence in
                        loadPreset(sequence)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Step list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                        StepCardView(
                            step: binding(for: item.id),
                            isExpanded: expandedStepID == item.id,
                            executionState: executionState(for: index),
                            onTap: { toggleExpanded(item.id) },
                            onRemove: { removeStep(item.id) }
                        )
                    }

                    Button(action: { showAddStepPopover.toggle() }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Step")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(runner.isRunning)
                    .popover(isPresented: $showAddStepPopover) {
                        AddStepPopover { step in
                            addStep(step)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Control bar
            ControlBar(
                isRunning: runner.isRunning,
                canRun: canRun,
                onRun: { runner.run(steps: steps.map(\.step)) },
                onStop: { runner.stop() },
                onReset: { showResetConfirmation = true }
            )
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .overlay(alignment: .bottom) {
            if let toast = runner.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: runner.toastMessage)
        .alert("Reset Sequence", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { steps.removeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all steps from the current sequence.")
        }
        .alert("Error", isPresented: .init(
            get: { runner.error != nil },
            set: { if !$0 { runner.error = nil } }
        )) {
            Button("OK") { runner.error = nil }
        } message: {
            Text(runner.error?.message ?? "")
        }
        .sheet(isPresented: $showSavePresetSheet) {
            SavePresetSheet(presetManager: presetManager) { name in
                var seq = CadenceSequence(name: name, steps: steps.map(\.step))
                try? presetManager.save(seq, name: name)
            }
        }
    }

    // MARK: - Helpers

    private func binding(for id: UUID) -> Binding<SequenceStep> {
        Binding(
            get: { steps.first(where: { $0.id == id })?.step ?? .wait(seconds: 5) },
            set: { newValue in
                if let index = steps.firstIndex(where: { $0.id == id }) {
                    steps[index].step = newValue
                }
            }
        )
    }

    private func executionState(for index: Int) -> StepExecutionState {
        guard runner.isRunning, let current = runner.currentStepIndex else { return .idle }
        if index < current { return .completed }
        if index == current { return .running }
        return .idle
    }

    private func toggleExpanded(_ id: UUID) {
        guard !runner.isRunning else { return }
        expandedStepID = expandedStepID == id ? nil : id
    }

    private func removeStep(_ id: UUID) {
        steps.removeAll(where: { $0.id == id })
        if expandedStepID == id { expandedStepID = nil }
    }

    private func addStep(_ step: SequenceStep) {
        let item = IdentifiableStep(step: step)
        steps.append(item)
        expandedStepID = item.id
        showAddStepPopover = false
    }

    private func loadPreset(_ sequence: CadenceSequence) {
        steps = sequence.steps.map { IdentifiableStep(step: $0) }
        expandedStepID = nil
        showPresetsPopover = false
    }
}

enum StepExecutionState {
    case idle
    case running
    case completed
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED (will have placeholder references to StepCardView, etc. — create stubs if needed)

- [ ] **Step 4: Commit**

```bash
git add Cadence/Views/ContentView.swift Cadence/Models/SequenceStep.swift
git commit -m "feat: add ContentView with full layout, state management, and step list"
```

---

## Task 9: StepCardView

**Files:**
- Create: `Cadence/Views/StepCardView.swift`

- [ ] **Step 1: Implement StepCardView**

```swift
import SwiftUI

struct StepCardView: View {
    @Binding var step: SequenceStep
    let isExpanded: Bool
    let executionState: StepExecutionState
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var pulseOpacity: Double = 1.0
    @State private var cameraList: [String] = []
    @State private var cameraListError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.typeName)
                        .font(.headline)
                    Text(step.configSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            // Expanded editing controls
            if isExpanded {
                Divider()
                stepEditor
            }
        }
        .padding(12)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: borderWidth)
                .opacity(executionState == .running ? pulseOpacity : 1.0)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            if executionState == .running {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            }
        }
        .onChange(of: executionState) { _, newValue in
            if newValue == .running {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.4
                }
            } else {
                pulseOpacity = 1.0
            }
        }
        .task(id: isExpanded) {
            if isExpanded, case .switchCamera = step {
                await fetchCameras()
            }
        }
    }

    private var borderColor: Color {
        switch executionState {
        case .idle:
            if !step.isComplete { return .yellow }
            return .clear
        case .running: return .green
        case .completed: return .green
        }
    }

    private var borderWidth: CGFloat {
        switch executionState {
        case .idle: step.isComplete ? 0 : 1.5
        case .running: 2
        case .completed: 1.5
        }
    }

    @ViewBuilder
    private var stepEditor: some View {
        switch step {
        case .capture(let delay):
            Stepper("Post-capture delay: \(delay)s", value: Binding(
                get: { delay },
                set: { step = .capture(postCaptureDelay: max($0, 3)) }
            ), in: 3...30)

        case .switchCamera(let currentName):
            if let error = cameraListError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if cameraList.isEmpty {
                Text("Connect cameras in Capture One to select")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Camera", selection: Binding(
                    get: { currentName ?? "" },
                    set: { step = .switchCamera(cameraName: $0.isEmpty ? nil : $0) }
                )) {
                    Text("Select camera...").tag("")
                    ForEach(cameraList, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }

        case .setISO(let value):
            Picker("ISO", selection: Binding(
                get: { value },
                set: { step = .setISO(value: $0) }
            )) {
                ForEach(SequenceStep.isoValues, id: \.self) { Text($0).tag($0) }
            }

        case .setAperture(let value):
            Picker("Aperture", selection: Binding(
                get: { value },
                set: { step = .setAperture(value: $0) }
            )) {
                ForEach(SequenceStep.apertureValues, id: \.self) { Text($0).tag($0) }
            }

        case .setShutterSpeed(let value):
            Picker("Shutter Speed", selection: Binding(
                get: { value },
                set: { step = .setShutterSpeed(value: $0) }
            )) {
                ForEach(SequenceStep.shutterSpeedValues, id: \.self) { Text($0).tag($0) }
            }

        case .autofocus:
            Text("Triggers autofocus then waits 1 second")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .moveFocus(let direction, let amount):
            HStack {
                Picker("Direction", selection: Binding(
                    get: { direction },
                    set: { step = .moveFocus(direction: $0, amount: amount) }
                )) {
                    ForEach(FocusDirection.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
                Picker("Amount", selection: Binding(
                    get: { amount },
                    set: { step = .moveFocus(direction: direction, amount: $0) }
                )) {
                    ForEach(FocusAmount.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
            }
            Text("Exact movement varies by camera and lens.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .wait(let seconds):
            Stepper("Wait: \(seconds)s", value: Binding(
                get: { seconds },
                set: { step = .wait(seconds: $0) }
            ), in: 1...60)
        }
    }

    private func fetchCameras() async {
        cameraListError = nil
        let result = AppleScriptBridge.fetchCameraList()
        switch result {
        case .success(let cameras):
            cameraList = cameras
            // If previously selected camera is no longer available, reset to nil
            if case .switchCamera(let name) = step, let name, !cameras.contains(name) {
                step = .switchCamera(cameraName: nil)
            }
        case .failure:
            cameraListError = "Connect cameras in Capture One to select"
            cameraList = []
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Cadence/Views/StepCardView.swift
git commit -m "feat: add StepCardView with inline editing and execution state borders"
```

---

## Task 10: AddStepPopover

**Files:**
- Create: `Cadence/Views/AddStepPopover.swift`

- [ ] **Step 1: Implement AddStepPopover**

```swift
import SwiftUI

struct AddStepPopover: View {
    let onAdd: (SequenceStep) -> Void

    private let stepOptions: [(name: String, description: String, step: SequenceStep)] = [
        ("Capture", "Fire the shutter on the selected camera", .capture(postCaptureDelay: 3)),
        ("Switch Camera", "Select a different connected camera", .switchCamera(cameraName: nil)),
        ("Set ISO", "Change the ISO setting", .setISO(value: "400")),
        ("Set Aperture", "Change the aperture setting", .setAperture(value: "f/5.6")),
        ("Set Shutter Speed", "Change the shutter speed", .setShutterSpeed(value: "1/125")),
        ("Autofocus", "Trigger autofocus on the selected camera", .autofocus),
        ("Move Focus", "Adjust focus position nearer or further", .moveFocus(direction: .nearer, amount: .medium)),
        ("Wait", "Pause for a number of seconds", .wait(seconds: 5)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(stepOptions, id: \.name) { option in
                Button(action: { onAdd(option.step) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.name)
                            .font(.headline)
                        Text(option.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                if option.name != stepOptions.last?.name {
                    Divider()
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 280)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Cadence/Views/AddStepPopover.swift
git commit -m "feat: add AddStepPopover with step type picker"
```

---

## Task 11: ControlBar

**Files:**
- Create: `Cadence/Views/ControlBar.swift`

- [ ] **Step 1: Implement ControlBar**

```swift
import SwiftUI

struct ControlBar: View {
    let isRunning: Bool
    let canRun: Bool
    let onRun: () -> Void
    let onStop: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack {
            if isRunning {
                Button("Stop", action: onStop)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            } else {
                Button("Run", action: onRun)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!canRun)
            }

            Spacer()

            Button("Reset", action: onReset)
                .buttonStyle(.bordered)
                .disabled(isRunning)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Cadence/Views/ControlBar.swift
git commit -m "feat: add ControlBar with Run/Stop/Reset"
```

---

## Task 12: PresetsPopover and SavePresetSheet

**Files:**
- Create: `Cadence/Views/PresetsPopover.swift`
- Create: `Cadence/Views/SavePresetSheet.swift`

- [ ] **Step 1: Implement PresetsPopover**

```swift
import SwiftUI

struct PresetsPopover: View {
    let presetManager: PresetManager
    let hasExistingSteps: Bool
    let onLoad: (CadenceSequence) -> Void

    @State private var presets: [String] = []
    @State private var showDeleteConfirmation: String?
    @State private var pendingLoadName: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if presets.isEmpty {
                Text("No saved presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(presets, id: \.self) { name in
                    Button(action: { attemptLoad(name) }) {
                        Text(name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            showDeleteConfirmation = name
                        }
                    }
                    if name != presets.last {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 220)
        .onAppear { refreshPresets() }
        .alert("Delete Preset", isPresented: .init(
            get: { showDeleteConfirmation != nil },
            set: { if !$0 { showDeleteConfirmation = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let name = showDeleteConfirmation {
                    try? presetManager.delete(name: name)
                    refreshPresets()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete preset \"\(showDeleteConfirmation ?? "")\"?")
        }
    }

    private func refreshPresets() {
        presets = (try? presetManager.listPresets()) ?? []
    }

    private func attemptLoad(_ name: String) {
        if hasExistingSteps {
            pendingLoadName = name
        } else {
            loadPreset(name)
        }
    }

    private func loadPreset(_ name: String) {
        guard let seq = try? presetManager.load(name: name) else { return }
        onLoad(seq)
        dismiss()
    }
}
```

Add a second alert for the load confirmation, after the delete alert:

```swift
        .alert("Replace Sequence", isPresented: .init(
            get: { pendingLoadName != nil },
            set: { if !$0 { pendingLoadName = nil } }
        )) {
            Button("Replace", role: .destructive) {
                if let name = pendingLoadName { loadPreset(name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Loading a preset will replace your current sequence.")
        }
```

- [ ] **Step 2: Implement SavePresetSheet**

```swift
import SwiftUI

struct SavePresetSheet: View {
    let presetManager: PresetManager
    let onSave: (String) -> Void

    @State private var presetName = ""
    @State private var showOverwriteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Preset")
                .font(.headline)

            TextField("Preset name", text: $presetName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { attemptSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .alert("Overwrite Preset", isPresented: $showOverwriteConfirmation) {
            Button("Overwrite", role: .destructive) { save() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A preset named \"\(presetName)\" already exists. Overwrite it?")
        }
    }

    private func attemptSave() {
        let name = presetName.trimmingCharacters(in: .whitespaces)
        if presetManager.presetExists(name: name) {
            showOverwriteConfirmation = true
        } else {
            save()
        }
    }

    private func save() {
        let name = presetName.trimmingCharacters(in: .whitespaces)
        onSave(name)
        dismiss()
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Cadence/Views/PresetsPopover.swift Cadence/Views/SavePresetSheet.swift
git commit -m "feat: add PresetsPopover and SavePresetSheet"
```

---

## Task 13: ToastView

**Files:**
- Create: `Cadence/Views/ToastView.swift`

- [ ] **Step 1: Implement ToastView**

```swift
import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.yellow.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.yellow.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Cadence/Views/ToastView.swift
git commit -m "feat: add ToastView for non-blocking warnings"
```

---

## Task 14: Integration Build & Manual Test

**Files:** None — verification only

- [ ] **Step 1: Full build**

Run: `xcodebuild -project Cadence.xcodeproj -scheme Cadence -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED with zero errors

- [ ] **Step 2: Run all tests**

Run: `xcodebuild test -project Cadence.xcodeproj -scheme CadenceTests -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 3: Fix any compilation errors or test failures**

Address any issues found. The most likely problems:
- Missing imports between files
- Type mismatches in bindings
- `@MainActor` isolation issues in SequenceRunner

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve integration build issues"
```

---

## Task 15: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

```markdown
# Cadence

A macOS utility that floats above Capture One and lets photographers build and run automated camera control sequences via AppleScript.

## Requirements

- macOS 13+
- Capture One Pro (any current version)
- Xcode 15+ (to build from source)

## Building

```bash
brew install xcodegen
xcodegen generate
open Cadence.xcodeproj
```

Build and run from Xcode (Cmd+R).

## Usage

1. Open Capture One and connect your camera(s)
2. Launch Cadence — it floats above Capture One
3. Add steps to build your sequence (capture, change settings, focus, wait)
4. Press Run to execute the sequence

## Supported Steps

- **Capture** — fire the shutter with configurable post-capture delay
- **Switch Camera** — select a different connected camera
- **Set ISO / Aperture / Shutter Speed** — change camera settings
- **Autofocus** — trigger autofocus
- **Move Focus** — adjust focus position (nearer/further, small/medium/large)
- **Wait** — pause for 1–60 seconds

## Presets

Save and load sequences as presets. Presets are stored as JSON in `~/Library/Application Support/Cadence/presets/`.

Note: Camera selections in Switch Camera steps are not saved in presets (cameras change between sessions). You'll need to re-select cameras after loading a preset.

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with build instructions and usage guide"
```
