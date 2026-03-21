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
