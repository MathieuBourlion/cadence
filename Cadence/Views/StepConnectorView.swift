import SwiftUI

/// Decorative connector displayed between step cards to indicate sequential execution.
struct StepConnectorView: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 2, height: 12)
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }
}
