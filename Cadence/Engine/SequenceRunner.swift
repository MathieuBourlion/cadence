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
        if case .failure = AppleScriptBridge.ping() {
            error = AppleScriptError(message: "Capture One is not running. Open Capture One and try again.")
            return
        }

        // Pre-flight: check all steps complete (belt-and-suspenders)
        guard steps.allSatisfy(\.isComplete) else {
            error = AppleScriptError(message: "Complete all steps before running.")
            return
        }

        isRunning = true
        error = nil
        currentStepIndex = nil

        runTask = Task {
            for (index, step) in steps.enumerated() {
                if Task.isCancelled { break }

                currentStepIndex = index

                // Execute the step's AppleScript (Wait has nil script — handled by delay below)
                if let script = AppleScriptBridge.scriptForStep(step) {
                    let result = AppleScriptBridge.execute(script)
                    if case .failure(let scriptError) = result {
                        error = scriptError
                        break
                    }

                    // Read-back verification for camera settings
                    if let readBackScript = AppleScriptBridge.readBackScript(for: step),
                       let requestedVal = requestedValue(for: step) {
                        if case .success(let actualValue) = AppleScriptBridge.executeForString(readBackScript) {
                            if actualValue != requestedVal {
                                let settingName = step.typeName.replacingOccurrences(of: "Set ", with: "")
                                toastMessage = "Could not set \(settingName) to \(requestedVal). Camera is using \(actualValue)."
                                // Auto-dismiss toast after 4 seconds
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
}
