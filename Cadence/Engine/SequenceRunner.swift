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
    private var toastTask: Task<Void, Never>?

    static func postStepDelay(for step: SequenceStep) -> TimeInterval {
        switch step {
        case .capture(let delay): return TimeInterval(max(delay, 3))
        case .autofocus:          return 0.0  // delay handled inside executeAutofocus
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

            // Activate Capture One and clear any focused UI element before starting
            await executeOffMainThread {
                AppleScriptBridge.execute(#"tell application "Capture One" to activate"#)
            }
            try? await Task.sleep(for: .seconds(0.5))
            if Task.isCancelled { isRunning = false; return }

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
        toastTask?.cancel()
        toastTask = nil
        isRunning = false
        currentStepIndex = nil
        currentIteration = 0
    }

    // MARK: - Step execution

    private func executeStep(_ step: SequenceStep) async -> Bool {
        // Autofocus: trigger, wait 1s, then revert
        if case .autofocus = step {
            return await executeAutofocus()
        }

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

    private func executeAutofocus() async -> Bool {
        let triggerScript = #"tell application "Capture One" to set autofocusing of camera of front document to true"#
        let result = await executeOffMainThread { AppleScriptBridge.execute(triggerScript) }
        if case .failure(let scriptError) = result {
            error = scriptError
            return false
        }
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            return false
        }
        let revertScript = #"tell application "Capture One" to set autofocusing of camera of front document to false"#
        await executeOffMainThread { AppleScriptBridge.execute(revertScript) }
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
                setScript: { #"tell application "Capture One" to set ISO of camera of front document to "\#($0)""# }
            )
        case .setAperture(let mode):
            guard case .relative(let dir, let steps) = mode else { return nil }
            return await executeRelative(
                fetch: AppleScriptBridge.fetchCurrentAperture,
                list: SequenceStep.apertureValues,
                direction: dir, steps: steps, settingName: "aperture",
                readBackScript: #"aperture of camera of front document of application "Capture One""#,
                setScript: { value in
                    let v = value.hasPrefix("f/") ? String(value.dropFirst(2)) : value
                    return #"tell application "Capture One" to set aperture of camera of front document to "\#(v)""#
                }
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
                    return #"tell application "Capture One" to set shutter speed of camera of front document to "\#(escaped)""#
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
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { toastMessage = nil }
        }
    }

    private func requestedValue(for step: SequenceStep) -> String? {
        switch step {
        case .setISO(let mode):
            if case .absolute(let value) = mode { return value }
            return nil
        case .setAperture(let mode):
            if case .absolute(let value) = mode {
                return value.hasPrefix("f/") ? String(value.dropFirst(2)) : value
            }
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
