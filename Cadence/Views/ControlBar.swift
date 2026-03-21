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
