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

        // Pre-flight: check all steps complete (belt-and-suspenders)
        guard steps.allSatisfy(\.isComplete) else {
            error = AppleScriptError(message: "Complete all steps before running.")
            return
        }

        isRunning = true
        error = nil
        currentStepIndex = nil

        runTask = Task {
            // Pre-flight: check Capture One is running (run off main thread)
            let pingResult = await Task.detached(priority: .userInitiated) {
                AppleScriptBridge.ping()
            }.value
            if case .failure = pingResult {
                error = AppleScriptError(message: "Capture One is not running. Open Capture One and try again.")
                isRunning = false
                return
            }

            for (index, step) in steps.enumerated() {
                if Task.isCancelled { break }

                currentStepIndex = index

                // Execute the step's AppleScript off main thread (Wait has nil script — handled by delay below)
                if let script = AppleScriptBridge.scriptForStep(step) {
                    let result = await executeOffMainThread { AppleScriptBridge.execute(script) }
                    if case .failure(let scriptError) = result {
                        error = scriptError
                        break
                    }

                    // Read-back verification
                    if let readBackScript = AppleScriptBridge.readBackScript(for: step),
                       let requestedVal = requestedValue(for: step) {
                        let readBackResult = await executeStringOffMainThread { AppleScriptBridge.executeForString(readBackScript) }
                        if case .success(let actualValue) = readBackResult {
                            if actualValue != requestedVal {
                                let settingName = step.typeName.replacingOccurrences(of: "Set ", with: "")
                                toastMessage = "Could not set \(settingName) to \(requestedVal). Camera is using \(actualValue)."
                                Task {
                                    try? await Task.sleep(for: .seconds(4))
                                    if !Task.isCancelled { toastMessage = nil }
                                }
                            }
                        }
                    }
                }

                // Post-step delay (includes Wait step duration)
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

    /// Runs an AppleScript call on a background thread, then returns to the main actor.
    private func executeOffMainThread(_ work: @escaping () -> Result<Void, AppleScriptError>) async -> Result<Void, AppleScriptError> {
        await Task.detached(priority: .userInitiated) { work() }.value
    }

    private func executeStringOffMainThread(_ work: @escaping () -> Result<String, AppleScriptError>) async -> Result<String, AppleScriptError> {
        await Task.detached(priority: .userInitiated) { work() }.value
    }
}
