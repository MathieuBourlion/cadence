# Cadence UI Enhancements — Design Spec

## Goal

Six improvements to the Cadence macOS app: visual step connectors, chevron-based expand/collapse, a "next camera" mode for Switch Camera, a repeat-count control in the run bar, and two-mode (absolute/relative) controls for ISO/Aperture/Shutter Speed.

---

## 1. Step Connectors

Between each pair of step cards in the `LazyVStack`, insert a small connector view:
- A thin vertical line (2pt, `.secondary` color, ~12pt tall)
- A small downward-pointing chevron (`chevron.down`, font size ~10pt, `.secondary` color) below the line

This is purely decorative — no interaction, no animation. Implemented as a dedicated `StepConnectorView` inserted between items in `ContentView`'s `ForEach`.

---

## 2. Chevron Expand/Collapse

The step card header row becomes three zones:

```
[chevron]  [title + summary — flexible]  [remove ×]
```

- Chevron uses `chevron.right` rotated 90° when expanded, 0° when collapsed, animated with `.spring`
- The header `HStack` is wrapped in a `Button(action: onTap)` with `.buttonStyle(.plain)` to handle expand/collapse — this is the only tap target for toggling
- The outer `VStack` loses its `.contentShape(Rectangle())` and `.onTapGesture` entirely; controls inside the editor (Pickers, Steppers) handle their own taps without conflict
- The remove button (`xmark`) remains on the trailing edge, unaffected

---

## 3. Switch Camera — "Next Camera" Mode

The step gains a segmented control at the top of its editor: **Specific | Next**

### Specific mode
Existing behavior: shows the camera picker (populated from Capture One). Requires a camera selection to be considered complete.

### Next mode
No further configuration. Always considered complete.

**Runtime behavior:**
1. Call `AppleScriptBridge.fetchCameraList()` to get `available camera identifiers of front document`
2. Call `AppleScriptBridge.fetchCurrentCamera()` to get `name of camera of front document` — returns `Result<String, AppleScriptError>`. If it fails, show an error alert and halt.
3. Select the camera at index `(currentIndex + 1) % cameraCount` — wraps from last back to first
4. If the camera list is empty, show an error alert and halt the sequence

`fetchCurrentCamera()` executes: `name of camera of front document of application "Capture One"` and returns the camera name as `Result<String, AppleScriptError>`.

**Model change:**

```swift
enum SwitchCameraMode: Codable, Equatable {
    case specific(cameraName: String?)
    case next
}

// SequenceStep.switchCamera becomes:
case switchCamera(mode: SwitchCameraMode)
```

**Encoding format:**
```json
// specific (camera name intentionally not persisted):
{ "type": "switchCamera", "config": { "mode": "specific" } }

// next:
{ "type": "switchCamera", "config": { "mode": "next" } }
```

**Codable migration:** Old JSON format (empty config `{}` with no `"mode"` key) decodes as `.specific(cameraName: nil)` — the missing `"mode"` key defaults to `"specific"`.

**`isComplete`:** `.specific(nil)` → false; `.specific(name)` → true; `.next` → true.

**`configSummary`:** `.specific(nil)` → "⚠ No camera selected"; `.specific(name)` → name; `.next` → "Next camera (wraps)"

**`fetchCameras()` in `StepCardView`:** The existing `.task` block trigger and reset logic must both be updated for the new model shape:

```swift
// .task trigger (was: case .switchCamera = step)
if isExpanded, case .switchCamera = step { await fetchCameras() }

// reset logic inside fetchCameras() (was: case .switchCamera(let name) = step)
if case .switchCamera(let mode) = step,
   case .specific(let name) = mode,
   let name, !cameras.contains(name) {
    step = .switchCamera(mode: .specific(cameraName: nil))
}
```

Camera list is fetched regardless of mode (Specific or Next) when expanded; it is only displayed in Specific mode.

---

## 4. Repeat Count in Control Bar

A `[−] ×N [+]` control sits to the left of the Run button in `ControlBar`.

- Range: ×1 to ×99. Default: ×1 (equivalent to current single-run behavior)
- Disabled while the sequence is running
- The `−` button is disabled at ×1; the `+` button is disabled at ×99
- `repeatCount: Int` lives in `ContentView` state — not persisted to presets

**Run button label:** `ControlBar` receives a `runLabel: String` prop (instead of hardcoding "Run"). `ContentView` computes this label:
- Not running: `"Run"`
- Running, ×1 repeat: `"Running…"`
- Running, multiple repeats: `"Running \(runner.currentIteration)/\(repeatCount)"`

This keeps `ControlBar` a dumb display component with no knowledge of iteration state.

**`SequenceRunner` changes:**
- `run(steps:)` gains a `repeatCount: Int` parameter (default 1 for backward compatibility at call sites)
- Adds `private(set) var currentIteration: Int = 0` (1-based, 0 when idle)
- The run loop wraps the existing step-execution loop in an outer `for iteration in 1...repeatCount` loop
- Between iterations, execution restarts from step 1 immediately with no added delay
- Cancellation checking (`Task.checkCancellation()`) continues to apply within each iteration

**Completed step state on repeat:** When iteration N+1 begins, `currentStepIndex` resets to 0. Steps that showed `.completed` at the end of iteration N will briefly show `.running` for the new first step before other steps reset. This is acceptable — no additional tracking across iterations is needed.

**ContentView call site:**
```swift
onRun: { runner.run(steps: steps.map(\.step), repeatCount: repeatCount) }
```

---

## 5. ISO / Aperture / Shutter Speed — Absolute and Relative Modes

Each of these three step types gains a segmented control: **Absolute | Relative**

### Absolute mode
Existing behavior: a `Picker` (dropdown) showing the static value list. Unchanged.

### Relative mode
Two controls:
- **Direction**: segmented `Up | Down`
- **Step count**: `[−] N [+]`, range 1–18 (clamping at runtime means out-of-range values are safe; the UI cap of 18 matches the longest list minus 1)

**`configSummary`** examples:
- Absolute ISO 400 → "ISO 400"
- Relative ISO +2 steps → "ISO +2 steps"
- Relative Aperture −1 step → "Aperture −1 step"

**Runtime behavior for relative mode (in `SequenceRunner`):**

The existing run loop has a single path: call `AppleScriptBridge.scriptForStep()` and execute. Relative-mode steps require a different path: read → compute → write. The runner must branch:

```
if step is relative-mode camera value:
    1. Call AppleScriptBridge.fetchCurrent[ISO|Aperture|ShutterSpeed]()
    2. If read fails: show non-blocking toast "Could not read current [setting]; skipping step" and continue
    3. Find index in static list. If not found: same toast, continue
    4. Compute new index = clamp(currentIndex ± steps, 0, list.count - 1)
    5. Execute the set-value script for the computed absolute value
    6. Apply existing verification + toast logic
else:
    existing absolute path (build script, execute, verify)
```

`AppleScriptBridge` gains three new read methods:
- `fetchCurrentISO() -> Result<String, AppleScriptError>`
- `fetchCurrentAperture() -> Result<String, AppleScriptError>`
- `fetchCurrentShutterSpeed() -> Result<String, AppleScriptError>`

Each executes the corresponding read AppleScript (e.g., `ISO of camera of front document of application "Capture One"`) and returns the string value.

**Model change** (non-generic, since the value is always `String`):

```swift
enum CameraValueMode: Codable, Equatable {
    case absolute(value: String)
    case relative(direction: RelativeDirection, steps: Int)
}

enum RelativeDirection: String, Codable, CaseIterable {
    case up, down
}

// SequenceStep cases become:
case setISO(mode: CameraValueMode)
case setAperture(mode: CameraValueMode)
case setShutterSpeed(mode: CameraValueMode)
```

**Encoding format:**
```json
// absolute:
{ "type": "setISO", "config": { "mode": "absolute", "value": "400" } }

// relative:
{ "type": "setISO", "config": { "mode": "relative", "direction": "up", "steps": 2 } }
```

**Codable migration:** Old format (`"value": "400"` with no `"mode"` key) decodes as `.absolute(value: "400")`.

**`isComplete`:** All modes always complete.

---

## 6. Move Focus — Unchanged

The Move Focus step is inherently relative (maps to AppleScript `adjust focus by amount N`). It keeps its existing Direction (Nearer/Further) + Amount (Small/Medium/Large) design. No absolute mode is added.

---

## Files Affected

| File | Change |
|------|--------|
| `Models/SequenceStep.swift` | Add `SwitchCameraMode`, `CameraValueMode`, `RelativeDirection`; update `switchCamera`, `setISO`, `setAperture`, `setShutterSpeed` cases and their Codable, `isComplete`, `configSummary` |
| `Views/StepCardView.swift` | Add chevron to header; wrap header in `Button`; remove outer tap gesture; update `switchCamera`, `setISO`, `setAperture`, `setShutterSpeed` editors; update `fetchCameras()` reset logic |
| `Views/ContentView.swift` | Insert `StepConnectorView` between steps; add `repeatCount` state; compute `runLabel`; pass repeat count and run label to `ControlBar`; pass repeat count to `runner.run()` |
| `Views/StepConnectorView.swift` | New file — thin line + chevron connector |
| `Views/ControlBar.swift` | Add `[−] ×N [+]` repeat control; accept `runLabel: String` and `repeatCount`/`onRepeatChange` props |
| `Engine/SequenceRunner.swift` | Accept `repeatCount` in `run()`; outer iteration loop; expose `currentIteration`; branch for relative-mode steps |
| `Engine/AppleScriptBridge.swift` | Add `fetchCurrentISO()`, `fetchCurrentAperture()`, `fetchCurrentShutterSpeed()`, `fetchCurrentCamera()` |

---

## Out of Scope

- Persisting repeat count to presets
- Delay between iterations
- Relative mode for Move Focus (already relative by design)
- Absolute mode for Move Focus
