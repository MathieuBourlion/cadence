import Foundation

/// Wraps an ordered list of steps and an optional preset name.
/// This is what gets serialized to JSON for preset storage.
struct CadenceSequence: Codable {
    var name: String?
    var steps: [SequenceStep]

    init(name: String? = nil, steps: [SequenceStep] = []) {
        self.name = name
        self.steps = steps
    }

    /// True if the sequence has steps and all steps are complete.
    var canRun: Bool {
        !steps.isEmpty && steps.allSatisfy(\.isComplete)
    }

    /// Returns a copy stripped of camera names (for preset saving).
    /// Switch Camera steps are reset to incomplete so the user
    /// must re-select cameras after loading.
    func strippedForPreset() -> CadenceSequence {
        let strippedSteps = steps.map { step -> SequenceStep in
            if case .switchCamera = step {
                return .switchCamera(cameraName: nil)
            }
            return step
        }
        return CadenceSequence(name: name, steps: strippedSteps)
    }
}
