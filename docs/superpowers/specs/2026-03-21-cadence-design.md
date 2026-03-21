# Cadence — Design Spec

**Date:** 2026-03-21
**Status:** Draft

Cadence is a macOS utility that floats above Capture One and lets studio photographers build and run automated camera control sequences. It communicates exclusively with Capture One Pro through AppleScript — no direct camera SDK dependency.

**Audience:** Studio photographers (ecomm, product), digitechs, and photographers doing bracketing, focus stacking, or timelapses. Distributed free via GitHub.

---

## Tech Stack

- Swift + SwiftUI, macOS 13+
- `NSAppleScript` for all Capture One communication (string-built scripts)
- `NSPanel` for floating window (SwiftUI hosted via `NSHostingView`)
- JSON files in `~/Library/Application Support/Cadence/` for presets
- Swift concurrency (`async/await`, `Task`) for execution engine
- No external dependencies

---

## Architecture

### Data Model

**`SequenceStep`** — enum with associated values, `Codable`, `Identifiable`:

| Case | Config | Defaults |
|---|---|---|
| `capture` | `postCaptureDelay: Int` | 3 (min 3, max 30) |
| `switchCamera` | `cameraName: String?` | nil (incomplete until set) |
| `setISO` | `value: String` | "400" |
| `setAperture` | `value: String` | "f/5.6" |
| `setShutterSpeed` | `value: String` | "1/125" |
| `autofocus` | (none) | — |
| `moveFocus` | `direction: Direction, amount: Amount` | .nearer, .medium |
| `wait` | `seconds: Int` | 5 (min 1, max 60) |

`Direction`: `nearer`, `further`
`Amount`: `small`, `medium`, `large`

Each step has a computed `isComplete` property. All steps are always complete except `switchCamera`, which is incomplete when `cameraName` is nil.

**`CadenceSequence`** — wraps `[SequenceStep]` plus optional preset name. This is what gets serialized to JSON.

### Key Classes

**`SequenceRunner`** (`@Observable`) — owns execution state: `currentStepIndex: Int?`, `isRunning: Bool`, `error: Error?`. Runs steps on a background `Task`. Cancellable via `task.cancel()`.

**`AppleScriptBridge`** — stateless struct with static methods. One method per command type. Each builds an AppleScript string and executes via `NSAppleScript.executeAndReturnError`.

Return types vary by method:
- Most commands return `Result<Void, AppleScriptError>` (fire-and-forget)
- Read-back commands (ISO, aperture, shutter speed) return `Result<String, AppleScriptError>` — extracted from the `NSAppleEventDescriptor.stringValue`
- Camera list query returns `Result<[String], AppleScriptError>` — the descriptor is iterated as a list of string items

`AppleScriptError` wraps the error dictionary from `NSAppleScript.executeAndReturnError`, exposing at minimum `message: String` (from `NSAppleScript.errorMessage` key) and optionally `errorNumber: Int`.

**`PresetManager`** — save/load/delete JSON files in `~/Library/Application Support/Cadence/presets/`.

### File Structure

```
Cadence/
├── App/
│   ├── CadenceApp.swift           -- entry point, NSApplicationDelegateAdaptor
│   └── FloatingPanel.swift        -- NSPanel subclass, window setup
├── Models/
│   ├── SequenceStep.swift         -- step enum + config + Codable
│   └── CadenceSequence.swift      -- step array wrapper, preset name
├── Engine/
│   ├── AppleScriptBridge.swift    -- all NSAppleScript execution
│   └── SequenceRunner.swift       -- async execution, cancellation, step tracking
├── Presets/
│   └── PresetManager.swift        -- save/load/delete JSON presets
├── Views/
│   ├── ContentView.swift          -- main layout (header, sequence list, control bar)
│   ├── StepCardView.swift         -- individual step card, inline editing, run state
│   ├── AddStepPopover.swift       -- step type picker popover
│   ├── PresetsPopover.swift       -- preset list popover
│   └── ControlBar.swift           -- Run / Stop / Reset
└── Utilities/
    └── ToastManager.swift         -- non-blocking warning toasts
```

---

## Window Behavior

- **NSPanel** with `NSWindow.Level.floating`, `.utilityWindow` style mask
- Default size: 380px wide, resizable vertically, minimum height 500px
- Fullscreen button removed from title bar style mask
- `NSVisualEffectView` with `.hudWindow` material as background for dark vibrancy
- Root SwiftUI view hosted via `NSHostingView`
- `.preferredColorScheme(.dark)` forced on the SwiftUI content
- Accent color: Capture One's orange/amber tone

---

## UI Design

### Principles

- Use standard SwiftUI controls everywhere (`Picker`, `Stepper`, `Button`, `TextField`, `List`, `.popover`, `.sheet`, `.contextMenu`, `.alert`)
- No custom-drawn controls — rely on native macOS dark mode widgets
- Apple design language updates flow through automatically
- Custom visuals limited to: step card borders (execution state)

### Layout

```
┌─────────────────────────────┐
│ Header                      │  fixed top
│ "Cadence"     [Save] [List] │
├─────────────────────────────┤
│                             │
│ ScrollView {                │  flex, scrollable
│   StepCardView              │
│   StepCardView              │
│   StepCardView              │
│   ...                       │
│   + Add Step                │
│ }                           │
│                             │
├─────────────────────────────┤
│ ControlBar                  │  fixed bottom
│ [Run]  [Stop]  [Reset]      │
└─────────────────────────────┘
```

### Header

- App name "Cadence" in medium weight, leading
- Toolbar buttons trailing: Save Preset (`square.and.arrow.down`), Presets (`list.bullet`)

### Step Cards

**Collapsed state (default):**
- Rounded rectangle, standard card appearance
- Step type as bold label ("Capture", "Set ISO", etc.)
- Config summary below ("ISO 400", "Post-capture delay: 3s")
- Remove button (x) on trailing edge
- Incomplete steps (Switch Camera with no camera): amber/yellow border or warning badge

**Expanded state (tapped):**
- Only one card expanded at a time
- Shows editing controls inline:

| Step | Controls |
|---|---|
| Capture | `Stepper` for post-capture delay (3–30s) |
| Switch Camera | `Picker` populated by querying C1 for `available camera identifiers` |
| Set ISO | `Picker` (menu style): 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 6400, 12800, 25600 |
| Set Aperture | `Picker` (menu style): f/1.4, f/1.8, f/2, f/2.8, f/3.5, f/4, f/5.6, f/6.3, f/7.1, f/8, f/11, f/13, f/16, f/18, f/22 |
| Set Shutter Speed | `Picker` (menu style): 1/4000, 1/2000, 1/1000, 1/500, 1/250, 1/125, 1/60, 1/30, 1/15, 1/8, 1/4, 1/2, 1", 2", 4", 8", 15", 30" |
| Autofocus | Static label: "Triggers autofocus then waits 1 second" |
| Move Focus | Two `Picker`s: Direction (Nearer/Further) + Amount (Small/Medium/Large). Note: "Exact movement varies by camera and lens." |
| Wait | `Stepper` for seconds (1–60) |

**Execution state borders:**
- Current step: green border with pulse animation (`.animation(.easeInOut.repeatForever)` on opacity)
- Completed steps: static green border
- Pending steps: default border

### Add Step

Full-width "+ Add Step" button at the bottom of the scroll view. Opens a `.popover` with all 8 step types, each showing name + one-line description:

| Step | Description |
|---|---|
| Capture | Fire the shutter on the selected camera |
| Switch Camera | Select a different connected camera |
| Set ISO | Change the ISO setting |
| Set Aperture | Change the aperture setting |
| Set Shutter Speed | Change the shutter speed |
| Autofocus | Trigger autofocus on the selected camera |
| Move Focus | Adjust focus position nearer or further |
| Wait | Pause for a number of seconds |

Tapping a type appends a new step with defaults and auto-expands it for editing.

### Control Bar

- **Run** — green accent, primary. Disabled when sequence is empty or any step is incomplete.
- **Stop** — red/destructive. Only visible while running, replaces Run.
- **Reset** — grey, secondary. Confirmation alert before clearing all steps.

---

## Switch Camera — Dynamic Camera List

Switch Camera steps query Capture One for connected cameras rather than using free text input.

**On step creation or expansion:**
1. Execute AppleScript: `available camera identifiers of front document of application "Capture One"`
2. Populate a `Picker` with the returned camera names
3. If C1 isn't running or no cameras connected: show message "Connect cameras in Capture One to select"

**On re-expansion of a configured step:**
- Re-query C1 to refresh the camera list
- If the previously selected camera is no longer available, revert the step to incomplete

**Preset serialization:**
- Switch Camera steps save with no camera name: `{ "type": "switchCamera", "config": {} }`
- On preset load, Switch Camera steps are incomplete — user must select a camera before running

---

## Execution Engine

### Sequence Runner Flow

1. **Pre-flight:** Execute `name of application "Capture One"` — if error, show alert: "Capture One is not running. Open Capture One and try again." Abort.
2. **Pre-flight:** Verify no steps are incomplete (belt-and-suspenders).
3. Set `isRunning = true`. Start a `Task` (not detached — inherits actor context from `@Observable` runner).
4. **For each step:**
   a. Update `currentStepIndex` on `@MainActor`
   b. Build AppleScript string via `AppleScriptBridge`
   c. Execute via `NSAppleScript.executeAndReturnError`
   d. Check for errors — if `NSAppleScript.executeAndReturnError` returns an error, show alert with error text, halt sequence
   e. For camera settings (ISO, aperture, shutter speed): execute a second read-back script, compare returned string to requested value. If different, show warning toast. (This is distinct from an AppleScript error — the set command succeeded but the camera used a different value.)
   f. Apply post-step delay via `try await Task.sleep(nanoseconds:)` — checks for cancellation. Delay source: `postCaptureDelay` for Capture steps (min 3s), hardcoded 1s for Autofocus, hardcoded 0.8s for Move Focus, `Task.sleep` for Wait steps, no delay for others.
5. **On cancel:** `task.cancel()` causes `Task.sleep` to throw `CancellationError`. Clean up, reset UI.
6. **On completion:** Reset `isRunning` and `currentStepIndex`.

### Post-Step Delays

| Step | Delay |
|---|---|
| Capture | User-configured, minimum 3 seconds |
| Autofocus | 1 second |
| Move Focus | 0.8 seconds |
| All others | None |

### AppleScript Commands

All commands target the **currently selected camera** in Capture One. Use the Switch Camera step to change which camera is active before issuing capture or settings commands.

| Step | AppleScript |
|---|---|
| Capture | `tell application "Capture One" to capture` |
| Switch Camera | `tell application "Capture One" to select camera of front document name "<cameraName>"` |
| Set ISO | `set ISO of camera of front document of application "Capture One" to "<value>"` |
| Set Aperture | `set aperture of camera of front document of application "Capture One" to "<value>"` |
| Set Shutter Speed | `set shutter speed of camera of front document of application "Capture One" to "<value>"` |
| Autofocus | `set autofocusing of camera of front document of application "Capture One" to true` |
| Move Focus | `tell application "Capture One" to adjust focus of camera of front document by amount <n> sync true` |
| Camera list | `available camera identifiers of front document of application "Capture One"` (returns list of strings) |
| Read-back (ISO) | `ISO of camera of front document of application "Capture One"` |
| Read-back (Aperture) | `aperture of camera of front document of application "Capture One"` |
| Read-back (Shutter) | `shutter speed of camera of front document of application "Capture One"` |
| Wait | No AppleScript — uses `Task.sleep` for cancellation support (see note below) |

**Note on shutter speed string values:** Values like `1"`, `2"`, `15"` contain double-quote characters. When building AppleScript strings, these must be escaped (e.g., `"1\""` or use single-character escaping). The implementation should handle this in `AppleScriptBridge`.

**Move Focus amount mapping:**

| Direction | Amount | Value |
|---|---|---|
| Nearer | Small | -1 |
| Nearer | Medium | -3 |
| Nearer | Large | -7 |
| Further | Small | 1 |
| Further | Medium | 3 |
| Further | Large | 7 |

### Wait Step Implementation Note

The Wait step should use Swift `Task.sleep` rather than AppleScript `delay`. This ensures cancellation works immediately when Stop is pressed — an AppleScript `delay` would block until complete.

---

## Preset System

### Save
- Toolbar button opens `.sheet` with text field for name + Save/Cancel
- Saves to `~/Library/Application Support/Cadence/presets/<name>.json`
- Creates directory if needed
- Overwrite confirmation if name already exists

### Load
- Toolbar button opens `.popover` listing saved presets
- Confirmation before replacing current sequence (if it has steps)
- Switch Camera steps load as incomplete

### Delete
- `.contextMenu` on preset name in popover
- Confirmation alert before deleting

### JSON Format

```json
{
  "name": "Product Shoot Bracket",
  "steps": [
    { "type": "capture", "config": { "postCaptureDelay": 3 } },
    { "type": "setISO", "config": { "value": "400" } },
    { "type": "switchCamera", "config": {} },
    { "type": "moveFocus", "config": { "direction": "nearer", "amount": "medium" } },
    { "type": "wait", "config": { "seconds": 5 } },
    { "type": "autofocus", "config": {} }
  ]
}
```

---

## Error Handling

| Situation | Behavior |
|---|---|
| C1 not running (on Run) | Alert: "Capture One is not running. Open Capture One and try again." Sequence doesn't start. |
| Incomplete steps | Run button disabled. Label: "Complete all steps before running." |
| Empty sequence | Run button disabled. |
| No cameras found (Switch Camera edit) | Message in card: "Connect cameras in Capture One to select." |
| Previously selected camera gone | Step reverts to incomplete on re-expansion. |
| Camera setting rejected | Non-blocking toast: "Could not set [setting] to [value]. Camera is using [actual]." Sequence continues. |
| Camera not found at runtime | Alert, sequence halts. |
| AppleScript error on any step | Alert with error description, sequence halts. |
| Task cancellation (Stop) | Sequence stops immediately, UI resets to idle. |

---

## Out of Scope (v1)

- Drag-to-reorder steps (use delete + re-add)
- Repeat/loop blocks
- Conditional logic
- Dynamic picker population from camera (except Switch Camera)
- Code signing / notarization (users build from source or download GitHub release)
- Windows support
- Direct camera SDK integration
- Undo for step deletion (use Reset cautiously)
