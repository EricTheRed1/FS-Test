import Cocoa
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    private let diskMonitor: DiskMonitor

    init(diskMonitor: DiskMonitor) {
        self.diskMonitor = diskMonitor
        let hostingController = NSHostingController(rootView: PreferencesView(diskMonitor: diskMonitor))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "FreeSpace Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.level = .floating
        window.setContentSize(NSSize(width: 360, height: 400))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
