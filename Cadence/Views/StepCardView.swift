import SwiftUI

struct StepCardView: View {
    @Binding var step: SequenceStep
    let isExpanded: Bool
    let executionState: StepExecutionState
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Text(step.typeName) // placeholder
    }
}

enum StepExecutionState {
    case idle
    case running
    case completed
}
