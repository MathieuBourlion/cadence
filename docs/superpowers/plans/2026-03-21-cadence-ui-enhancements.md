# Cadence UI Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add step connectors, chevron expand/collapse, next-camera mode, repeat count, and absolute/relative modes for ISO/aperture/shutter speed.

**Architecture:** Model changes first (Task 1–2) establish the new API. Task 2 restores test compilation and must run after Task 1. Task 3 (bridge) must precede Task 4 (runner). Task 6 (StepCardView) requires Task 1. Task 8 (ContentView) requires Tasks 4–7.

**Tech Stack:** Swift + SwiftUI, macOS 14+, XCTest, NSAppleScript

---

## File Map

| File | Status | Change |
|------|--------|--------|
| `Cadence/Models/SequenceStep.swift` | Modify | New enums + updated cases |
| `Cadence/Models/CadenceSequence.swift` | Modify | Update `strippedForPreset()` |
| `CadenceTests/CadenceTests.swift` | Modify | Update all tests for new API, add new tests |
| `Cadence/Engine/AppleScriptBridge.swift` | Modify | New fetch methods, updated `scriptForStep`/`readBackScript` |
| `Cadence/Engine/SequenceRunner.swift` | Modify | repeatCount, iteration loop, relative mode branch |
| `Cadence/Views/StepConnectorView.swift` | **Create** | Thin line + chevron between steps |
| `Cadence/Views/StepCardView.swift` | Modify | Chevron header, updated editors |
| `Cadence/Views/ControlBar.swift` | Modify | Repeat count control, `runLabel` prop |
| `Cadence/Views/ContentView.swift` | Modify | Connectors, repeatCount state, wire new props |
| `Cadence/Views/AddStepPopover.swift` | Modify | Update default step constructors for new API |

---

## Task 1: Update SequenceStep model

**Files:**
- Modify: `Cadence/Models/SequenceStep.swift`
- Modify: `Cadence/Models/CadenceSequence.swift`

This task breaks existing tests — that's expected. Task 2 fixes them.

- [ ] **Step 1: Replace `SequenceStep.swift` entirely**

```swift
import Foundation

// MARK: - Supporting Types

enum FocusDirection: String, Codable, CaseIterable {
    case nearer
    case further
}

enum FocusAmount: String, Codable, CaseIterable {
    case small
    case medium
    case large
}

enum RelativeDirection: String, Codable, CaseIterable {
    case up, down
}

enum SwitchCameraMode: Codable, Equatable {
    case specific(cameraName: String?)
    case next

    private enum CodingKeys: String, CodingKey { case mode }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = (try? container.decode(String.self, forKey: .mode)) ?? "specific"
        self = mode == "next" ? .next : .specific(cameraName: nil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .specific: try container.encode("specific", forKey: .mode)
        case .next:     try container.encode("next", forKey: .mode)
        }
    }
}

enum CameraValueMode: Codable, Equatable {
    case absolute(value: String)
    case relative(direction: RelativeDirection, steps: Int)

    private enum CodingKeys: String, CodingKey { case mode, value, direction, steps }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = (try? container.decode(String.self, forKey: .mode)) ?? "absolute"
        if mode == "relative" {
            let direction = try container.decode(RelativeDirection.self, forKey: .direction)
            let steps = try container.decode(Int.self, forKey: .steps)
            self = .relative(direction: direction, steps: steps)
        } else {
            let value = (try? container.decode(String.self, forKey: .value)) ?? ""
            self = .absolute(value: value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .absolute(let value):
            try container.encode("absolute", forKey: .mode)
            try container.encode(value, forKey: .value)
        case .relative(let direction, let steps):
            try container.encode("relative", forKey: .mode)
            try container.encode(direction, forKey: .direction)
            try container.encode(steps, forKey: .steps)
        }
    }
}

// MARK: - SequenceStep

/// An individual step in a Cadence sequence.
/// Note: SequenceStep does NOT conform to Identifiable. When used in SwiftUI Lists,
/// wrap in IdentifiableStep (see ContentView) to get a stable UUID per list item.
enum SequenceStep: Codable, Equatable {
    case capture(postCaptureDelay: Int)
    case switchCamera(mode: SwitchCameraMode)
    case setISO(mode: CameraValueMode)
    case setAperture(mode: CameraValueMode)
    case setShutterSpeed(mode: CameraValueMode)
    case autofocus
    case moveFocus(direction: FocusDirection, amount: FocusAmount)
    case wait(seconds: Int)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case type, config }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "capture":
            let config = try container.decode([String: Int].self, forKey: .config)
            self = .capture(postCaptureDelay: config["postCaptureDelay"] ?? 3)
        case "switchCamera":
            // Old format: {} — defaults to .specific(nil) via SwitchCameraMode.init
            // New format: { "mode": "specific" } or { "mode": "next" }
            let mode = (try? container.decode(SwitchCameraMode.self, forKey: .config)) ?? .specific(cameraName: nil)
            self = .switchCamera(mode: mode)
        case "setISO":
            // Old format: { "value": "400" } — defaults to .absolute via CameraValueMode.init
            let mode = (try? container.decode(CameraValueMode.self, forKey: .config)) ?? .absolute(value: "400")
            self = .setISO(mode: mode)
        case "setAperture":
            let mode = (try? container.decode(CameraValueMode.self, forKey: .config)) ?? .absolute(value: "f/5.6")
            self = .setAperture(mode: mode)
        case "setShutterSpeed":
            let mode = (try? container.decode(CameraValueMode.self, forKey: .config)) ?? .absolute(value: "1/125")
            self = .setShutterSpeed(mode: mode)
        case "autofocus":
            self = .autofocus
        case "moveFocus":
            let config = try container.decode([String: String].self, forKey: .config)
            let direction = FocusDirection(rawValue: config["direction"] ?? "nearer") ?? .nearer
            let amount = FocusAmount(rawValue: config["amount"] ?? "medium") ?? .medium
            self = .moveFocus(direction: direction, amount: amount)
        case "wait":
            let config = try container.decode([String: Int].self, forKey: .config)
            self = .wait(seconds: config["seconds"] ?? 5)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                debugDescription: "Unknown step type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .capture(let delay):
            try container.encode("capture", forKey: .type)
            try container.encode(["postCaptureDelay": delay], forKey: .config)
        case .switchCamera(let mode):
            try container.encode("switchCamera", forKey: .type)
            try container.encode(mode, forKey: .config)
        case .setISO(let mode):
            try container.encode("setISO", forKey: .type)
            try container.encode(mode, forKey: .config)
        case .setAperture(let mode):
            try container.encode("setAperture", forKey: .type)
            try container.encode(mode, forKey: .config)
        case .setShutterSpeed(let mode):
            try container.encode("setShutterSpeed", forKey: .type)
            try container.encode(mode, forKey: .config)
        case .autofocus:
            try container.encode("autofocus", forKey: .type)
            try container.encode([String: String](), forKey: .config)
        case .moveFocus(let direction, let amount):
            try container.encode("moveFocus", forKey: .type)
            try container.encode(["direction": direction.rawValue, "amount": amount.rawValue], forKey: .config)
        case .wait(let seconds):
            try container.encode("wait", forKey: .type)
            try container.encode(["seconds": seconds], forKey: .config)
        }
    }

    // MARK: - Validation

    var isComplete: Bool {
        if case .switchCamera(let mode) = self,
           case .specific(let name) = mode {
            return name != nil
        }
        return true
    }

    // MARK: - Display

    var typeName: String {
        switch self {
        case .capture:        return "Capture"
        case .switchCamera:   return "Switch Camera"
        case .setISO:         return "Set ISO"
        case .setAperture:    return "Set Aperture"
        case .setShutterSpeed: return "Set Shutter Speed"
        case .autofocus:      return "Autofocus"
        case .moveFocus:      return "Move Focus"
        case .wait:           return "Wait"
        }
    }

    var configSummary: String {
        switch self {
        case .capture(let delay):
            return "Post-capture delay: \(delay)s"
        case .switchCamera(let mode):
            switch mode {
            case .specific(let name): return name ?? "⚠ No camera selected"
            case .next:               return "Next camera (wraps)"
            }
        case .setISO(let mode):
            switch mode {
            case .absolute(let value): return "ISO \(value)"
            case .relative(let dir, let steps):
                return "ISO \(dir == .up ? "+" : "−")\(steps) step\(steps == 1 ? "" : "s")"
            }
        case .setAperture(let mode):
            switch mode {
            case .absolute(let value): return value
            case .relative(let dir, let steps):
                return "Aperture \(dir == .up ? "+" : "−")\(steps) step\(steps == 1 ? "" : "s")"
            }
        case .setShutterSpeed(let mode):
            switch mode {
            case .absolute(let value): return value
            case .relative(let dir, let steps):
                return "Shutter \(dir == .up ? "+" : "−")\(steps) step\(steps == 1 ? "" : "s")"
            }
        case .autofocus:
            return "Triggers autofocus, waits 1s"
        case .moveFocus(let direction, let amount):
            return "\(amount.rawValue.capitalized) step \(direction.rawValue)"
        case .wait(let seconds):
            return "Wait \(seconds)s"
        }
    }

    // MARK: - Static value lists

    static let isoValues = ["100", "125", "160", "200", "250", "320", "400", "500",
                             "640", "800", "1000", "1250", "1600", "2000", "2500",
                             "3200", "6400", "12800", "25600"]

    static let apertureValues = ["f/1.4", "f/1.8", "f/2", "f/2.8", "f/3.5", "f/4",
                                  "f/5.6", "f/6.3", "f/7.1", "f/8", "f/11", "f/13",
                                  "f/16", "f/18", "f/22"]

    static let shutterSpeedValues = ["1/4000", "1/2000", "1/1000", "1/500", "1/250",
                                      "1/125", "1/60", "1/30", "1/15", "1/8", "1/4",
                                      "1/2", "1\"", "2\"", "4\"", "8\"", "15\"", "30\""]
}
```

- [ ] **Step 2: Update `strippedForPreset()` in `CadenceSequence.swift`**

Replace the `strippedForPreset` method:

```swift
/// Returns a copy stripped of specific camera names (for preset saving).
/// .specific(cameraName:) steps are reset to nil so the user must re-select after loading.
/// .next steps are preserved as-is.
func strippedForPreset() -> CadenceSequence {
    let strippedSteps = steps.map { step -> SequenceStep in
        if case .switchCamera(let mode) = step, case .specific = mode {
            return .switchCamera(mode: .specific(cameraName: nil))
        }
        return step
    }
    return CadenceSequence(name: name, steps: strippedSteps)
}
```

- [ ] **Step 3: Verify the model compiles (tests will fail — that's expected)**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild build -scheme Cadence -configuration Debug 2>&1 | grep -E "(error:|BUILD)"
```

Expected: Errors in CadenceTests.swift (old API). No errors in Cadence target files.

- [ ] **Step 4: Commit**

```bash
git add "Cadence/Models/SequenceStep.swift" "Cadence/Models/CadenceSequence.swift"
git commit -m "feat: add SwitchCameraMode and CameraValueMode to SequenceStep model"
```

---

## Task 2: Update tests for new model API

**Files:**
- Modify: `CadenceTests/CadenceTests.swift`

Replace the entire file. All old `.switchCamera(cameraName:)`, `.setISO(value:)` etc. are replaced with the new API. New tests are added for the new model behaviors.

- [ ] **Step 1: Replace `CadenceTests.swift` entirely**

```swift
import XCTest
@testable import Cadence

final class SequenceStepTests: XCTestCase {

    // MARK: - isComplete

    func test_captureStep_isComplete() {
        XCTAssertTrue(SequenceStep.capture(postCaptureDelay: 3).isComplete)
    }

    func test_switchCamera_specific_withName_isComplete() {
        XCTAssertTrue(SequenceStep.switchCamera(mode: .specific(cameraName: "Canon R5")).isComplete)
    }

    func test_switchCamera_specific_withoutName_isIncomplete() {
        XCTAssertFalse(SequenceStep.switchCamera(mode: .specific(cameraName: nil)).isComplete)
    }

    func test_switchCamera_next_isComplete() {
        XCTAssertTrue(SequenceStep.switchCamera(mode: .next).isComplete)
    }

    func test_allOtherSteps_areComplete() {
        let steps: [SequenceStep] = [
            .setISO(mode: .absolute(value: "400")),
            .setISO(mode: .relative(direction: .up, steps: 2)),
            .setAperture(mode: .absolute(value: "f/5.6")),
            .setAperture(mode: .relative(direction: .down, steps: 1)),
            .setShutterSpeed(mode: .absolute(value: "1/125")),
            .setShutterSpeed(mode: .relative(direction: .up, steps: 3)),
            .autofocus,
            .moveFocus(direction: .nearer, amount: .medium),
            .wait(seconds: 5)
        ]
        for step in steps {
            XCTAssertTrue(step.isComplete, "Expected \(step) to be complete")
        }
    }

    // MARK: - configSummary

    func test_configSummary_switchCamera_specificWithName() {
        XCTAssertEqual(
            SequenceStep.switchCamera(mode: .specific(cameraName: "Canon R5")).configSummary,
            "Canon R5"
        )
    }

    func test_configSummary_switchCamera_specificNoName() {
        XCTAssertEqual(
            SequenceStep.switchCamera(mode: .specific(cameraName: nil)).configSummary,
            "⚠ No camera selected"
        )
    }

    func test_configSummary_switchCamera_next() {
        XCTAssertEqual(
            SequenceStep.switchCamera(mode: .next).configSummary,
            "Next camera (wraps)"
        )
    }

    func test_configSummary_setISO_absolute() {
        XCTAssertEqual(SequenceStep.setISO(mode: .absolute(value: "800")).configSummary, "ISO 800")
    }

    func test_configSummary_setISO_relative_up_plural() {
        XCTAssertEqual(
            SequenceStep.setISO(mode: .relative(direction: .up, steps: 2)).configSummary,
            "ISO +2 steps"
        )
    }

    func test_configSummary_setISO_relative_down_singular() {
        XCTAssertEqual(
            SequenceStep.setISO(mode: .relative(direction: .down, steps: 1)).configSummary,
            "ISO −1 step"
        )
    }

    func test_configSummary_setAperture_relative() {
        XCTAssertEqual(
            SequenceStep.setAperture(mode: .relative(direction: .up, steps: 3)).configSummary,
            "Aperture +3 steps"
        )
    }

    func test_configSummary_setShutterSpeed_relative() {
        XCTAssertEqual(
            SequenceStep.setShutterSpeed(mode: .relative(direction: .down, steps: 1)).configSummary,
            "Shutter −1 step"
        )
    }

    // MARK: - Codable round-trip (new format)

    func test_capture_roundTrip() throws {
        let original = SequenceStep.capture(postCaptureDelay: 7)
        let decoded = try roundTrip(original)
        XCTAssertEqual(original, decoded)
    }

    func test_switchCamera_specific_roundTrip_cameraNameDropped() throws {
        // Camera name is intentionally NOT saved; decoded as nil
        let original = SequenceStep.switchCamera(mode: .specific(cameraName: "Canon R5"))
        let decoded = try roundTrip(original)
        XCTAssertEqual(decoded, .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_switchCamera_next_roundTrip() throws {
        let original = SequenceStep.switchCamera(mode: .next)
        let decoded = try roundTrip(original)
        XCTAssertEqual(original, decoded)
    }

    func test_setISO_absolute_roundTrip() throws {
        let original = SequenceStep.setISO(mode: .absolute(value: "800"))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setISO_relative_roundTrip() throws {
        let original = SequenceStep.setISO(mode: .relative(direction: .up, steps: 3))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setAperture_absolute_roundTrip() throws {
        let original = SequenceStep.setAperture(mode: .absolute(value: "f/8"))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setAperture_relative_roundTrip() throws {
        let original = SequenceStep.setAperture(mode: .relative(direction: .down, steps: 2))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setShutterSpeed_absolute_roundTrip() throws {
        let original = SequenceStep.setShutterSpeed(mode: .absolute(value: "1/250"))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_setShutterSpeed_relative_roundTrip() throws {
        let original = SequenceStep.setShutterSpeed(mode: .relative(direction: .up, steps: 1))
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_autofocus_roundTrip() throws {
        XCTAssertEqual(try roundTrip(.autofocus), .autofocus)
    }

    func test_moveFocus_roundTrip() throws {
        let original = SequenceStep.moveFocus(direction: .further, amount: .large)
        XCTAssertEqual(try roundTrip(original), original)
    }

    func test_wait_roundTrip() throws {
        let original = SequenceStep.wait(seconds: 15)
        XCTAssertEqual(try roundTrip(original), original)
    }

    // MARK: - Codable migration (old JSON format → new API)

    func test_switchCamera_oldFormat_decodesAsSpecificNil() throws {
        // Old format: { "type": "switchCamera", "config": {} }
        let json = #"{"type":"switchCamera","config":{}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_setISO_oldFormat_decodesAsAbsolute() throws {
        // Old format: { "type": "setISO", "config": { "value": "400" } }
        let json = #"{"type":"setISO","config":{"value":"400"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .setISO(mode: .absolute(value: "400")))
    }

    func test_setAperture_oldFormat_decodesAsAbsolute() throws {
        let json = #"{"type":"setAperture","config":{"value":"f\/5.6"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .setAperture(mode: .absolute(value: "f/5.6")))
    }

    func test_setShutterSpeed_oldFormat_decodesAsAbsolute() throws {
        let json = #"{"type":"setShutterSpeed","config":{"value":"1\/125"}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SequenceStep.self, from: json)
        XCTAssertEqual(decoded, .setShutterSpeed(mode: .absolute(value: "1/125")))
    }

    // MARK: - JSON format (spec compliance)

    func test_capture_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.capture(postCaptureDelay: 3))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "capture")
        XCTAssertEqual((json["config"] as! [String: Int])["postCaptureDelay"], 3)
    }

    func test_wait_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.wait(seconds: 10))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "wait")
        XCTAssertEqual((json["config"] as! [String: Int])["seconds"], 10)
    }

    func test_switchCamera_specific_JSONFormat_hasNoName() throws {
        let data = try JSONEncoder().encode(SequenceStep.switchCamera(mode: .specific(cameraName: "Canon")))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "switchCamera")
        let config = json["config"] as! [String: String]
        XCTAssertEqual(config["mode"], "specific")
        XCTAssertNil(config["cameraName"], "Camera name should not be saved")
    }

    func test_switchCamera_next_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.switchCamera(mode: .next))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual((json["config"] as! [String: String])["mode"], "next")
    }

    func test_setISO_absolute_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.setISO(mode: .absolute(value: "400")))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let config = json["config"] as! [String: String]
        XCTAssertEqual(config["mode"], "absolute")
        XCTAssertEqual(config["value"], "400")
    }

    func test_setISO_relative_JSONFormat() throws {
        let data = try JSONEncoder().encode(SequenceStep.setISO(mode: .relative(direction: .up, steps: 2)))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let config = json["config"] as! [String: Any]
        XCTAssertEqual(config["mode"] as? String, "relative")
        XCTAssertEqual(config["direction"] as? String, "up")
        XCTAssertEqual(config["steps"] as? Int, 2)
    }

    // MARK: - typeName

    func test_typeName() {
        XCTAssertEqual(SequenceStep.capture(postCaptureDelay: 3).typeName, "Capture")
        XCTAssertEqual(SequenceStep.switchCamera(mode: .next).typeName, "Switch Camera")
        XCTAssertEqual(SequenceStep.setISO(mode: .absolute(value: "400")).typeName, "Set ISO")
        XCTAssertEqual(SequenceStep.setAperture(mode: .absolute(value: "f/5.6")).typeName, "Set Aperture")
        XCTAssertEqual(SequenceStep.setShutterSpeed(mode: .absolute(value: "1/125")).typeName, "Set Shutter Speed")
        XCTAssertEqual(SequenceStep.autofocus.typeName, "Autofocus")
        XCTAssertEqual(SequenceStep.moveFocus(direction: .nearer, amount: .medium).typeName, "Move Focus")
        XCTAssertEqual(SequenceStep.wait(seconds: 5).typeName, "Wait")
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
}

final class CadenceSequenceTests: XCTestCase {

    func test_emptySequence_cannotRun() {
        XCTAssertFalse(CadenceSequence(steps: []).canRun)
    }

    func test_sequenceWithCompleteSteps_canRun() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .setISO(mode: .absolute(value: "400"))
        ])
        XCTAssertTrue(seq.canRun)
    }

    func test_sequenceWithIncompleteStep_cannotRun() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .switchCamera(mode: .specific(cameraName: nil))
        ])
        XCTAssertFalse(seq.canRun)
    }

    func test_switchCamera_next_isConsideredComplete_forCanRun() {
        let seq = CadenceSequence(steps: [
            .switchCamera(mode: .next)
        ])
        XCTAssertTrue(seq.canRun)
    }

    func test_strippedForPreset_clearsSpecificCameraName() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 3),
            .switchCamera(mode: .specific(cameraName: "Canon EOS R5")),
            .setISO(mode: .absolute(value: "400"))
        ])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[1], .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_strippedForPreset_preservesNextMode() {
        let seq = CadenceSequence(steps: [.switchCamera(mode: .next)])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[0], .switchCamera(mode: .next))
    }

    func test_strippedForPreset_preservesOtherSteps() {
        let seq = CadenceSequence(steps: [
            .capture(postCaptureDelay: 5),
            .switchCamera(mode: .specific(cameraName: "Canon R5")),
            .wait(seconds: 10)
        ])
        let stripped = seq.strippedForPreset()
        XCTAssertEqual(stripped.steps[0], .capture(postCaptureDelay: 5))
        XCTAssertEqual(stripped.steps[2], .wait(seconds: 10))
    }

    func test_codableRoundTrip() throws {
        let original = CadenceSequence(name: "Test Preset", steps: [
            .capture(postCaptureDelay: 3),
            .setISO(mode: .absolute(value: "800")),
            .wait(seconds: 5)
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CadenceSequence.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.steps.count, original.steps.count)
    }
}

final class AppleScriptBridgeTests: XCTestCase {

    // MARK: - scriptForStep

    func test_capture_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.capture(postCaptureDelay: 3)),
            #"tell application "Capture One" to capture"#
        )
    }

    func test_switchCamera_specific_withName_script() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(mode: .specific(cameraName: "Canon EOS R5")))
        XCTAssertEqual(script, #"tell application "Capture One" to select camera of front document name "Canon EOS R5""#)
    }

    func test_switchCamera_specific_withoutName_returnsNil() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.switchCamera(mode: .specific(cameraName: nil))))
    }

    func test_switchCamera_next_returnsNil() {
        // .next is handled by SequenceRunner, not scriptForStep
        XCTAssertNil(AppleScriptBridge.scriptForStep(.switchCamera(mode: .next)))
    }

    func test_switchCamera_withQuoteInName_escapesCorrectly() {
        let script = AppleScriptBridge.scriptForStep(.switchCamera(mode: .specific(cameraName: #"Canon "R5""#)))
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains(#"\"R5\""#))
    }

    func test_setISO_absolute_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.setISO(mode: .absolute(value: "400"))),
            #"set ISO of camera of front document of application "Capture One" to "400""#
        )
    }

    func test_setISO_relative_returnsNil() {
        // Relative mode is handled by SequenceRunner
        XCTAssertNil(AppleScriptBridge.scriptForStep(.setISO(mode: .relative(direction: .up, steps: 2))))
    }

    func test_setAperture_absolute_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.setAperture(mode: .absolute(value: "f/5.6"))),
            #"set aperture of camera of front document of application "Capture One" to "f/5.6""#
        )
    }

    func test_setAperture_relative_returnsNil() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.setAperture(mode: .relative(direction: .down, steps: 1))))
    }

    func test_setShutterSpeed_absolute_plainValue_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.setShutterSpeed(mode: .absolute(value: "1/125"))),
            #"set shutter speed of camera of front document of application "Capture One" to "1/125""#
        )
    }

    func test_setShutterSpeed_absolute_longExposure_escapesQuote() {
        let script = AppleScriptBridge.scriptForStep(.setShutterSpeed(mode: .absolute(value: #"1""#)))
        XCTAssertNotNil(script)
        XCTAssertTrue(script!.contains(#"\""#))
    }

    func test_setShutterSpeed_relative_returnsNil() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.setShutterSpeed(mode: .relative(direction: .up, steps: 1))))
    }

    func test_autofocus_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.autofocus),
            #"set autofocusing of camera of front document of application "Capture One" to true"#
        )
    }

    func test_moveFocus_nearerMedium_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.moveFocus(direction: .nearer, amount: .medium)),
            #"tell application "Capture One" to adjust focus of camera of front document by amount -3 sync true"#
        )
    }

    func test_moveFocus_furtherLarge_script() {
        XCTAssertEqual(
            AppleScriptBridge.scriptForStep(.moveFocus(direction: .further, amount: .large)),
            #"tell application "Capture One" to adjust focus of camera of front document by amount 7 sync true"#
        )
    }

    func test_wait_returnsNilScript() {
        XCTAssertNil(AppleScriptBridge.scriptForStep(.wait(seconds: 5)))
    }

    // MARK: - moveFocusAmount

    func test_moveFocusAmount_allCombinations() {
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .nearer, amount: .small), -1)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .nearer, amount: .medium), -3)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .nearer, amount: .large), -7)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .further, amount: .small), 1)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .further, amount: .medium), 3)
        XCTAssertEqual(AppleScriptBridge.moveFocusAmount(direction: .further, amount: .large), 7)
    }

    // MARK: - readBackScript

    func test_readBackScript_forISO_absolute() {
        XCTAssertEqual(
            AppleScriptBridge.readBackScript(for: .setISO(mode: .absolute(value: "400"))),
            #"ISO of camera of front document of application "Capture One""#
        )
    }

    func test_readBackScript_forISO_relative_isNil() {
        // Relative handles its own read-back inside SequenceRunner
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .setISO(mode: .relative(direction: .up, steps: 1))))
    }

    func test_readBackScript_forAperture_absolute() {
        XCTAssertEqual(
            AppleScriptBridge.readBackScript(for: .setAperture(mode: .absolute(value: "f/5.6"))),
            #"aperture of camera of front document of application "Capture One""#
        )
    }

    func test_readBackScript_forAperture_relative_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .setAperture(mode: .relative(direction: .down, steps: 1))))
    }

    func test_readBackScript_forShutterSpeed_absolute() {
        XCTAssertEqual(
            AppleScriptBridge.readBackScript(for: .setShutterSpeed(mode: .absolute(value: "1/125"))),
            #"shutter speed of camera of front document of application "Capture One""#
        )
    }

    func test_readBackScript_forShutterSpeed_relative_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .setShutterSpeed(mode: .relative(direction: .up, steps: 1))))
    }

    func test_readBackScript_forCapture_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .capture(postCaptureDelay: 3)))
    }

    func test_readBackScript_forWait_isNil() {
        XCTAssertNil(AppleScriptBridge.readBackScript(for: .wait(seconds: 5)))
    }
}

final class PresetManagerTests: XCTestCase {

    var tempDirectory: URL!
    var manager: PresetManager!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CadenceTests-\(UUID().uuidString)", isDirectory: true)
        manager = PresetManager(presetsDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func test_saveAndLoad_roundTrip() throws {
        let seq = CadenceSequence(name: "Test", steps: [
            .capture(postCaptureDelay: 5),
            .setISO(mode: .absolute(value: "800"))
        ])
        try manager.save(seq, name: "Test")
        let loaded = try manager.load(name: "Test")
        XCTAssertEqual(loaded.steps.count, 2)
        XCTAssertEqual(loaded.steps[0], .capture(postCaptureDelay: 5))
        XCTAssertEqual(loaded.steps[1], .setISO(mode: .absolute(value: "800")))
    }

    func test_save_stripsSpecificCameraName() throws {
        let seq = CadenceSequence(steps: [.switchCamera(mode: .specific(cameraName: "Canon R5"))])
        try manager.save(seq, name: "CamTest")
        let loaded = try manager.load(name: "CamTest")
        XCTAssertEqual(loaded.steps[0], .switchCamera(mode: .specific(cameraName: nil)))
    }

    func test_save_preservesNextCameraMode() throws {
        let seq = CadenceSequence(steps: [.switchCamera(mode: .next)])
        try manager.save(seq, name: "NextCam")
        let loaded = try manager.load(name: "NextCam")
        XCTAssertEqual(loaded.steps[0], .switchCamera(mode: .next))
    }

    func test_delete_removesFile() throws {
        let seq = CadenceSequence(steps: [.autofocus])
        try manager.save(seq, name: "ToDelete")
        XCTAssertTrue(manager.presetExists(name: "ToDelete"))
        try manager.delete(name: "ToDelete")
        XCTAssertFalse(manager.presetExists(name: "ToDelete"))
    }

    func test_listPresets_returnsAlphabeticallySorted() throws {
        for name in ["Zebra", "Alpha", "Mango"] {
            try manager.save(CadenceSequence(steps: [.autofocus]), name: name)
        }
        XCTAssertEqual(try manager.listPresets(), ["Alpha", "Mango", "Zebra"])
    }

    func test_listPresets_emptyWhenNoPresets() throws {
        XCTAssertTrue(try manager.listPresets().isEmpty)
    }

    func test_presetExists_falseForMissing() {
        XCTAssertFalse(manager.presetExists(name: "NonExistent"))
    }
}

@MainActor
final class SequenceRunnerTests: XCTestCase {

    func test_initialState() {
        let runner = SequenceRunner()
        XCTAssertFalse(runner.isRunning)
        XCTAssertNil(runner.currentStepIndex)
        // NOTE: currentIteration test is in Task 4 (added after SequenceRunner is updated)
        XCTAssertNil(runner.error)
        XCTAssertNil(runner.toastMessage)
    }

    func test_postStepDelay_capture_usesConfiguredDelay() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .capture(postCaptureDelay: 5)), 5.0)
    }

    func test_postStepDelay_capture_enforcesMinimum3() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .capture(postCaptureDelay: 1)), 3.0)
    }

    func test_postStepDelay_autofocus_is1s() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .autofocus), 1.0)
    }

    func test_postStepDelay_moveFocus_is0_8s() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .moveFocus(direction: .nearer, amount: .small)), 0.8)
    }

    func test_postStepDelay_wait_usesSeconds() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .wait(seconds: 10)), 10.0)
    }

    func test_postStepDelay_setISO_isZero() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .setISO(mode: .absolute(value: "400"))), 0.0)
    }

    func test_postStepDelay_switchCamera_isZero() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .switchCamera(mode: .specific(cameraName: "Canon"))), 0.0)
    }

    func test_postStepDelay_switchCamera_next_isZero() {
        XCTAssertEqual(SequenceRunner.postStepDelay(for: .switchCamera(mode: .next)), 0.0)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild test -scheme Cadence -destination 'platform=macOS' 2>&1 | grep -E "(Test (passed|failed)|error:|PASS|FAIL)" | head -30
```

Expected: All tests pass. Fix any failures before continuing.

- [ ] **Step 3: Commit**

```bash
git add "CadenceTests/CadenceTests.swift"
git commit -m "test: update all tests for new SequenceStep model API, add new model tests"
```

---

## Task 3: Update AppleScriptBridge

**Files:**
- Modify: `Cadence/Engine/AppleScriptBridge.swift`

- [ ] **Step 1: Update `scriptForStep` for new model shapes**

Replace the `switchCamera`, `setISO`, `setAperture`, `setShutterSpeed` cases in `scriptForStep`:

```swift
case .switchCamera(let mode):
    switch mode {
    case .specific(let name):
        guard let name else { return nil }
        let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
        return #"tell application "Capture One" to select camera of front document name "\#(escaped)""#
    case .next:
        return nil  // Handled by SequenceRunner.executeNextCamera()
    }

case .setISO(let mode):
    guard case .absolute(let value) = mode else { return nil }
    return #"set ISO of camera of front document of application "Capture One" to "\#(value)""#

case .setAperture(let mode):
    guard case .absolute(let value) = mode else { return nil }
    return #"set aperture of camera of front document of application "Capture One" to "\#(value)""#

case .setShutterSpeed(let mode):
    guard case .absolute(let value) = mode else { return nil }
    let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
    return #"set shutter speed of camera of front document of application "Capture One" to "\#(escaped)""#
```

- [ ] **Step 2: Update `readBackScript` for new model shapes**

Replace the `setISO`, `setAperture`, `setShutterSpeed` cases:

```swift
case .setISO(let mode):
    guard case .absolute = mode else { return nil }  // relative handles its own read-back
    return #"ISO of camera of front document of application "Capture One""#
case .setAperture(let mode):
    guard case .absolute = mode else { return nil }
    return #"aperture of camera of front document of application "Capture One""#
case .setShutterSpeed(let mode):
    guard case .absolute = mode else { return nil }
    return #"shutter speed of camera of front document of application "Capture One""#
```

- [ ] **Step 3: Add the four new fetch methods after the `fetchCameraList` method**

```swift
// MARK: - Current value reads (for relative mode)

static func fetchCurrentCamera() -> Result<String, AppleScriptError> {
    executeForString(#"name of camera of front document of application "Capture One""#)
}

static func fetchCurrentISO() -> Result<String, AppleScriptError> {
    executeForString(#"ISO of camera of front document of application "Capture One""#)
}

static func fetchCurrentAperture() -> Result<String, AppleScriptError> {
    executeForString(#"aperture of camera of front document of application "Capture One""#)
}

static func fetchCurrentShutterSpeed() -> Result<String, AppleScriptError> {
    executeForString(#"shutter speed of camera of front document of application "Capture One""#)
}
```

- [ ] **Step 4: Run tests**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild test -scheme Cadence -destination 'platform=macOS' 2>&1 | grep -E "(Test (passed|failed)|error:)" | head -20
```

Expected: All tests pass (bridge tests now cover new API).

- [ ] **Step 5: Commit**

```bash
git add "Cadence/Engine/AppleScriptBridge.swift"
git commit -m "feat: update AppleScriptBridge for new step model, add fetch methods for relative mode"
```

---

## Task 4: Update SequenceRunner

**Files:**
- Modify: `Cadence/Engine/SequenceRunner.swift`

Replace the entire file:

- [ ] **Step 1: Replace `SequenceRunner.swift`**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class SequenceRunner {
    var isRunning = false
    var currentStepIndex: Int?
    var currentIteration: Int = 0
    var error: AppleScriptError?
    var toastMessage: String?

    private var runTask: Task<Void, Never>?

    static func postStepDelay(for step: SequenceStep) -> TimeInterval {
        switch step {
        case .capture(let delay): return TimeInterval(max(delay, 3))
        case .autofocus:          return 1.0
        case .moveFocus:          return 0.8
        case .wait(let seconds):  return TimeInterval(seconds)
        default:                  return 0.0
        }
    }

    func run(steps: [SequenceStep], repeatCount: Int = 1) {
        guard !isRunning else { return }
        guard steps.allSatisfy(\.isComplete) else {
            error = AppleScriptError(message: "Complete all steps before running.")
            return
        }

        isRunning = true
        error = nil
        currentStepIndex = nil
        currentIteration = 0

        runTask = Task {
            let pingResult = await Task.detached(priority: .userInitiated) {
                AppleScriptBridge.ping()
            }.value
            if case .failure = pingResult {
                error = AppleScriptError(message: "Capture One is not running. Open Capture One and try again.")
                isRunning = false
                return
            }

            let total = max(1, repeatCount)
            outer: for iteration in 1...total {
                if Task.isCancelled { break }
                currentIteration = iteration

                for (index, step) in steps.enumerated() {
                    if Task.isCancelled { break outer }
                    currentStepIndex = index

                    let success = await executeStep(step)
                    if !success { break outer }

                    let delay = Self.postStepDelay(for: step)
                    if delay > 0 {
                        do {
                            try await Task.sleep(for: .seconds(delay))
                        } catch {
                            break outer
                        }
                    }
                }
            }

            isRunning = false
            currentStepIndex = nil
            currentIteration = 0
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        currentStepIndex = nil
        currentIteration = 0
    }

    // MARK: - Step execution

    private func executeStep(_ step: SequenceStep) async -> Bool {
        // Next camera: special read-then-select path
        if case .switchCamera(let mode) = step, case .next = mode {
            return await executeNextCamera()
        }

        // Relative camera value: read → compute → write path
        if let result = await tryExecuteRelative(step) {
            return result
        }

        // Standard path: build script → execute → verify
        guard let script = AppleScriptBridge.scriptForStep(step) else {
            return true  // No-op steps (Wait)
        }
        let result = await executeOffMainThread { AppleScriptBridge.execute(script) }
        if case .failure(let scriptError) = result {
            error = scriptError
            return false
        }
        await verifyAbsoluteStep(step)
        return true
    }

    private func executeNextCamera() async -> Bool {
        let listResult = await Task.detached(priority: .userInitiated) {
            AppleScriptBridge.fetchCameraList()
        }.value
        guard case .success(let cameras) = listResult, !cameras.isEmpty else {
            error = AppleScriptError(message: "No cameras found in Capture One.")
            return false
        }

        let currentResult = await Task.detached(priority: .userInitiated) {
            AppleScriptBridge.fetchCurrentCamera()
        }.value
        guard case .success(let currentName) = currentResult else {
            error = AppleScriptError(message: "Could not determine current camera.")
            return false
        }
        let currentIndex = cameras.firstIndex(of: currentName) ?? 0

        let nextName = cameras[(currentIndex + 1) % cameras.count]
        let escaped = nextName.replacingOccurrences(of: "\"", with: "\\\"")
        let script = #"tell application "Capture One" to select camera of front document name "\#(escaped)""#
        let result = await executeOffMainThread { AppleScriptBridge.execute(script) }
        if case .failure(let scriptError) = result {
            error = scriptError
            return false
        }
        return true
    }

    /// Returns nil if `step` is not a relative-mode step.
    /// Returns true/false (continue?) if the step was handled as relative.
    private func tryExecuteRelative(_ step: SequenceStep) async -> Bool? {
        switch step {
        case .setISO(let mode):
            guard case .relative(let dir, let steps) = mode else { return nil }
            return await executeRelative(
                fetch: AppleScriptBridge.fetchCurrentISO,
                list: SequenceStep.isoValues,
                direction: dir, steps: steps, settingName: "ISO",
                readBackScript: #"ISO of camera of front document of application "Capture One""#,
                setScript: { #"set ISO of camera of front document of application "Capture One" to "\#($0)""# }
            )
        case .setAperture(let mode):
            guard case .relative(let dir, let steps) = mode else { return nil }
            return await executeRelative(
                fetch: AppleScriptBridge.fetchCurrentAperture,
                list: SequenceStep.apertureValues,
                direction: dir, steps: steps, settingName: "aperture",
                readBackScript: #"aperture of camera of front document of application "Capture One""#,
                setScript: { #"set aperture of camera of front document of application "Capture One" to "\#($0)""# }
            )
        case .setShutterSpeed(let mode):
            guard case .relative(let dir, let steps) = mode else { return nil }
            return await executeRelative(
                fetch: AppleScriptBridge.fetchCurrentShutterSpeed,
                list: SequenceStep.shutterSpeedValues,
                direction: dir, steps: steps, settingName: "shutter speed",
                readBackScript: #"shutter speed of camera of front document of application "Capture One""#,
                setScript: { value in
                    let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
                    return #"set shutter speed of camera of front document of application "Capture One" to "\#(escaped)""#
                }
            )
        default:
            return nil
        }
    }

    private func executeRelative(
        fetch: @escaping @Sendable () -> Result<String, AppleScriptError>,
        list: [String],
        direction: RelativeDirection,
        steps: Int,
        settingName: String,
        readBackScript: String,
        setScript: @escaping @Sendable (String) -> String
    ) async -> Bool {
        let fetchResult = await Task.detached(priority: .userInitiated) { fetch() }.value
        guard case .success(let currentValue) = fetchResult,
              let currentIndex = list.firstIndex(of: currentValue) else {
            showToast("Could not read current \(settingName); skipping step")
            return true
        }

        let delta = direction == .up ? steps : -steps
        let newIndex = max(0, min(list.count - 1, currentIndex + delta))
        let newValue = list[newIndex]

        let result = await executeOffMainThread { AppleScriptBridge.execute(setScript(newValue)) }
        if case .failure(let scriptError) = result {
            error = scriptError
            return false
        }

        // Read-back verification
        let readResult = await executeStringOffMainThread { AppleScriptBridge.executeForString(readBackScript) }
        if case .success(let actual) = readResult, actual != newValue {
            showToast("Could not set \(settingName) to \(newValue). Camera is using \(actual).")
        }
        return true
    }

    private func verifyAbsoluteStep(_ step: SequenceStep) async {
        guard let readBackScript = AppleScriptBridge.readBackScript(for: step),
              let requestedVal = requestedValue(for: step) else { return }
        let result = await executeStringOffMainThread { AppleScriptBridge.executeForString(readBackScript) }
        if case .success(let actual) = result, actual != requestedVal {
            let settingName = step.typeName.replacingOccurrences(of: "Set ", with: "")
            showToast("Could not set \(settingName) to \(requestedVal). Camera is using \(actual).")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            toastMessage = nil
        }
    }

    private func requestedValue(for step: SequenceStep) -> String? {
        switch step {
        case .setISO(let mode):
            if case .absolute(let value) = mode { return value }
            return nil
        case .setAperture(let mode):
            if case .absolute(let value) = mode { return value }
            return nil
        case .setShutterSpeed(let mode):
            if case .absolute(let value) = mode { return value }
            return nil
        default:
            return nil
        }
    }

    private func executeOffMainThread(_ work: @escaping () -> Result<Void, AppleScriptError>) async -> Result<Void, AppleScriptError> {
        await Task.detached(priority: .userInitiated) { work() }.value
    }

    private func executeStringOffMainThread(_ work: @escaping () -> Result<String, AppleScriptError>) async -> Result<String, AppleScriptError> {
        await Task.detached(priority: .userInitiated) { work() }.value
    }
}
```

- [ ] **Step 2: Add `currentIteration` test to `CadenceTests.swift`**

In `SequenceRunnerTests.test_initialState`, add the assertion that was deferred from Task 2:

```swift
func test_initialState() {
    let runner = SequenceRunner()
    XCTAssertFalse(runner.isRunning)
    XCTAssertNil(runner.currentStepIndex)
    XCTAssertEqual(runner.currentIteration, 0)  // added here after SequenceRunner updated
    XCTAssertNil(runner.error)
    XCTAssertNil(runner.toastMessage)
}
```

- [ ] **Step 3: Run tests**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild test -scheme Cadence -destination 'platform=macOS' 2>&1 | grep -E "(Test (passed|failed)|error:)" | head -20
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add "Cadence/Engine/SequenceRunner.swift" "CadenceTests/CadenceTests.swift"
git commit -m "feat: add repeat count, iteration tracking, and relative mode execution to SequenceRunner"
```

---

## Task 5: Create StepConnectorView

**Files:**
- Create: `Cadence/Views/StepConnectorView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

/// Decorative connector displayed between step cards to indicate sequential execution.
struct StepConnectorView: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 2, height: 12)
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild build -scheme Cadence -configuration Debug 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Cadence/Views/StepConnectorView.swift"
git commit -m "feat: add StepConnectorView for sequential step indicators"
```

---

## Task 6: Update StepCardView

**Files:**
- Modify: `Cadence/Views/StepCardView.swift`

Replace the entire file:

- [ ] **Step 1: Replace `StepCardView.swift`**

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
            // Header row — wrapped in Button to handle expand/collapse
            Button(action: onTap) {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(duration: 0.2), value: isExpanded)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.typeName)
                            .font(.headline)
                            .foregroundStyle(.primary)
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
            }
            .buttonStyle(.plain)

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
                withAnimation(.default) { pulseOpacity = 1.0 }
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
        case .idle:      return step.isComplete ? .clear : .yellow
        case .running:   return .green
        case .completed: return .green
        }
    }

    private var borderWidth: CGFloat {
        switch executionState {
        case .idle:      return step.isComplete ? 0 : 1.5
        case .running:   return 2
        case .completed: return 1.5
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

        case .switchCamera(let mode):
            switchCameraEditor(mode: mode)

        case .setISO(let mode):
            cameraValueEditor(
                mode: mode,
                label: "ISO",
                values: SequenceStep.isoValues,
                defaultAbsolute: "400",
                makeStep: { step = .setISO(mode: $0) }
            )

        case .setAperture(let mode):
            cameraValueEditor(
                mode: mode,
                label: "Aperture",
                values: SequenceStep.apertureValues,
                defaultAbsolute: "f/5.6",
                makeStep: { step = .setAperture(mode: $0) }
            )

        case .setShutterSpeed(let mode):
            cameraValueEditor(
                mode: mode,
                label: "Shutter Speed",
                values: SequenceStep.shutterSpeedValues,
                defaultAbsolute: "1/125",
                makeStep: { step = .setShutterSpeed(mode: $0) }
            )

        case .autofocus:
            Text("Triggers autofocus then waits 1 second")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .moveFocus(let direction, let amount):
            VStack(alignment: .leading, spacing: 4) {
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
            }

        case .wait(let seconds):
            Stepper("Wait: \(seconds)s", value: Binding(
                get: { seconds },
                set: { step = .wait(seconds: $0) }
            ), in: 1...60)
        }
    }

    @ViewBuilder
    private func switchCameraEditor(mode: SwitchCameraMode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode", selection: Binding(
                get: { if case .next = mode { return "next" } else { return "specific" } },
                set: { newMode in
                    step = .switchCamera(mode: newMode == "next" ? .next : .specific(cameraName: nil))
                }
            )) {
                Text("Specific").tag("specific")
                Text("Next").tag("next")
            }
            .pickerStyle(.segmented)

            switch mode {
            case .specific:
                if let error = cameraListError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                } else if cameraList.isEmpty {
                    Text("Connect cameras in Capture One to select")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker("Camera", selection: Binding(
                        get: { if case .specific(let name) = mode { return name ?? "" } else { return "" } },
                        set: { step = .switchCamera(mode: .specific(cameraName: $0.isEmpty ? nil : $0)) }
                    )) {
                        Text("Select camera...").tag("")
                        ForEach(cameraList, id: \.self) { Text($0).tag($0) }
                    }
                }
            case .next:
                Text("Selects the next camera in Capture One's list, wrapping back to the first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cameraValueEditor(
        mode: CameraValueMode,
        label: String,
        values: [String],
        defaultAbsolute: String,
        makeStep: @escaping (CameraValueMode) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode", selection: Binding(
                get: { if case .relative = mode { return "relative" } else { return "absolute" } },
                set: { newMode in
                    if newMode == "relative" {
                        makeStep(.relative(direction: .up, steps: 1))
                    } else {
                        makeStep(.absolute(value: defaultAbsolute))
                    }
                }
            )) {
                Text("Absolute").tag("absolute")
                Text("Relative").tag("relative")
            }
            .pickerStyle(.segmented)

            switch mode {
            case .absolute(let value):
                Picker(label, selection: Binding(
                    get: { value },
                    set: { makeStep(.absolute(value: $0)) }
                )) {
                    ForEach(values, id: \.self) { Text($0).tag($0) }
                }

            case .relative(let dir, let steps):
                HStack {
                    Picker("Direction", selection: Binding(
                        get: { dir },
                        set: { makeStep(.relative(direction: $0, steps: steps)) }
                    )) {
                        Text("Up").tag(RelativeDirection.up)
                        Text("Down").tag(RelativeDirection.down)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 120)

                    Stepper("\(steps) step\(steps == 1 ? "" : "s")", value: Binding(
                        get: { steps },
                        set: { makeStep(.relative(direction: dir, steps: max(1, min(18, $0)))) }
                    ), in: 1...18)
                }
            }
        }
    }

    private func fetchCameras() async {
        cameraListError = nil
        let result = AppleScriptBridge.fetchCameraList()
        switch result {
        case .success(let cameras):
            cameraList = cameras
            // If previously selected camera is no longer available, reset to incomplete
            if case .switchCamera(let mode) = step,
               case .specific(let name) = mode,
               let name, !cameras.contains(name) {
                step = .switchCamera(mode: .specific(cameraName: nil))
            }
        case .failure:
            cameraListError = "Connect cameras in Capture One to select"
            cameraList = []
        }
    }
}

enum StepExecutionState {
    case idle
    case running
    case completed
}
```

- [ ] **Step 2: Verify build**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild build -scheme Cadence -configuration Debug 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Cadence/Views/StepCardView.swift"
git commit -m "feat: chevron expand/collapse header, absolute/relative editors for ISO/aperture/shutter, next camera mode editor"
```

---

## Task 7: Update ControlBar

**Files:**
- Modify: `Cadence/Views/ControlBar.swift`

- [ ] **Step 1: Replace `ControlBar.swift`**

```swift
import SwiftUI

struct ControlBar: View {
    let isRunning: Bool
    let canRun: Bool
    let runLabel: String
    let repeatCount: Int
    let onRun: () -> Void
    let onStop: () -> Void
    let onReset: () -> Void
    let onRepeatCountChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Repeat count stepper
            HStack(spacing: 4) {
                Button {
                    onRepeatCountChange(repeatCount - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .disabled(isRunning || repeatCount <= 1)

                Text("×\(repeatCount)")
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .center)

                Button {
                    onRepeatCountChange(repeatCount + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .disabled(isRunning || repeatCount >= 99)
            }

            if isRunning {
                Text(runLabel)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Button("Stop", action: onStop)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            } else {
                Button(runLabel, action: onRun)
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

- [ ] **Step 2: Verify build**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild build -scheme Cadence -configuration Debug 2>&1 | tail -3
```

Expected: Compile error in ContentView.swift (new ControlBar props) — that's expected, fixed in Task 8.

- [ ] **Step 3: Commit**

```bash
git add "Cadence/Views/ControlBar.swift"
git commit -m "feat: add repeat count stepper and runLabel prop to ControlBar"
```

---

## Task 8: Update ContentView and AddStepPopover

**Files:**
- Modify: `Cadence/Views/ContentView.swift`
- Modify: `Cadence/Views/AddStepPopover.swift`

- [ ] **Step 1: Add `repeatCount` state and `runLabel` computed property to `ContentView`**

After `@State private var showResetConfirmation = false`, add:
```swift
@State private var repeatCount: Int = 1
```

After the `canRun` computed property, add:
```swift
private var runLabel: String {
    guard runner.isRunning else { return "Run" }
    return repeatCount > 1 ? "Running \(runner.currentIteration)/\(repeatCount)" : "Running…"
}
```

- [ ] **Step 2: Insert `StepConnectorView` between steps in `ContentView`**

In the `ForEach` inside the `ScrollView`, add a connector after each card except the last:

```swift
ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
    StepCardView(
        step: binding(for: item.id),
        isExpanded: expandedStepID == item.id,
        executionState: executionState(for: index),
        onTap: { toggleExpanded(item.id) },
        onRemove: { removeStep(item.id) }
    )
    .disabled(runner.isRunning)

    if index < steps.count - 1 {
        StepConnectorView()
    }
}
```

- [ ] **Step 3: Update the `ControlBar` call in `ContentView`**

Replace the existing `ControlBar(...)` call:

```swift
ControlBar(
    isRunning: runner.isRunning,
    canRun: canRun,
    runLabel: runLabel,
    repeatCount: repeatCount,
    onRun: { runner.run(steps: steps.map(\.step), repeatCount: repeatCount) },
    onStop: { runner.stop() },
    onReset: { showResetConfirmation = true },
    onRepeatCountChange: { repeatCount = max(1, min(99, $0)) }
)
```

- [ ] **Step 4: Update `AddStepPopover.swift` default constructors**

In `stepOptions`, update the three affected defaults:

```swift
("Switch Camera", "Select a different connected camera", .switchCamera(mode: .specific(cameraName: nil))),
("Set ISO", "Change the ISO setting", .setISO(mode: .absolute(value: "400"))),
("Set Aperture", "Change the aperture setting", .setAperture(mode: .absolute(value: "f/5.6"))),
("Set Shutter Speed", "Change the shutter speed", .setShutterSpeed(mode: .absolute(value: "1/125"))),
```

- [ ] **Step 5: Verify build and run all tests**

```bash
cd "/Users/bou/Documents/Capture One/cadence"
xcodebuild test -scheme Cadence -destination 'platform=macOS' 2>&1 | grep -E "(Test (passed|failed)|error:|BUILD)" | head -20
```

Expected: `** BUILD SUCCEEDED **` and all tests pass.

- [ ] **Step 6: Commit**

```bash
git add "Cadence/Views/ContentView.swift" "Cadence/Views/AddStepPopover.swift"
git commit -m "feat: wire step connectors, repeat count, and runLabel into ContentView"
```
