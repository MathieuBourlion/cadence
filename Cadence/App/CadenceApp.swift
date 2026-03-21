import SwiftUI
import AppKit

@main
struct CadenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Window managed by AppDelegate via FloatingPanel
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
        panel = FloatingPanel(contentView: contentView)
        panel?.delegate = self
        panel?.orderFrontRegardless()
    }

    // NSPanels are not counted as "windows" by AppKit for this callback,
    // so a popover (real NSWindow) closing would trigger termination.
    // Return false and terminate explicitly when the panel itself closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}
