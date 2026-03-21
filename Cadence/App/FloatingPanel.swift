import AppKit
import SwiftUI

class FloatingPanel: NSPanel {

    init(contentView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Float above all other windows
        level = .floating
        isFloatingPanel = true

        // Fixed width, resizable height, minimum height 500
        minSize = NSSize(width: 380, height: 500)
        maxSize = NSSize(width: 380, height: CGFloat.greatestFiniteMagnitude)

        // No fullscreen capability
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Vibrancy background (.hudWindow = dark blurred panel look)
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active

        // SwiftUI content with dark scheme forced
        let hostingView = NSHostingView(rootView:
            contentView
                .preferredColorScheme(.dark)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        self.contentView = visualEffect
        titlebarAppearsTransparent = true
        title = "Cadence"

        center()
    }
}
