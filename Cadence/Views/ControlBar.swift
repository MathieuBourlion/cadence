import SwiftUI

struct ControlBar: View {
    let isRunning: Bool
    let canRun: Bool
    let onRun: () -> Void
    let onStop: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack {
            Text("Run")
            Text("Stop")
            Text("Reset")
        }
    }
}
