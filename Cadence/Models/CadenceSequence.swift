import Foundation

/// Wraps an ordered list of steps and an optional preset name.
/// This is what gets serialized to JSON for preset storage.
struct CadenceSequence: Codable {
    var name: String?
    var steps: [SequenceStep]
    /// Parallel to `steps`. `true` = step runs on first iteration only and is skipped on repeats.
    /// Optional for backward compatibility with presets saved before this field existed.
    var firstIterationOnly: [Bool]?

    init(name: String? = nil, steps: [SequenceStep] = [], firstIterationOnly: [Bool]? = nil) {
        self.name = name
        self.steps = steps
        self.firstIterationOnly = firstIterationOnly
    }

    /// True if the sequence has steps and all steps are complete.
    var canRun: Bool {
        !steps.isEmpty && steps.allSatisfy(\.isComplete)
    }

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
        return CadenceSequence(name: name, steps: strippedSteps, firstIterationOnly: firstIterationOnly)
    }
}
