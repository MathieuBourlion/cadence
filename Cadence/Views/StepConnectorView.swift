import SwiftUI

struct StepConnectorView: View {
    let onInsert: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 2, height: 8)
                Button(action: onInsert) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(isHovered ? Color.accentColor : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.borderless)
                .onHover { isHovered = $0 }
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 2, height: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            Spacer()
        }
    }
}
