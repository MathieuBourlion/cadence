import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .padding(8)
            .background(.yellow.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
