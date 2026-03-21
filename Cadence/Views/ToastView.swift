import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.yellow.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.yellow.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal)
    }
}
