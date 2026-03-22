import SwiftUI

extension View {
    /// Applies `.bordered` button style on macOS 26+ (gets automatic liquid glass),
    /// falls back to `.borderless` on older systems.
    @ViewBuilder
    func adaptiveToolbarButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.bordered)
        } else {
            self.buttonStyle(.plain)
        }
    }
}
