import Cocoa
import Combine

final class StatusBarController {
    private let diskMonitor: DiskMonitor
    private let statusItem: NSStatusItem
    private var cancellables: Set<AnyCancellable> = []
    private lazy var preferencesWindowController = PreferencesWindowController(diskMonitor: diskMonitor)

    init(diskMonitor: DiskMonitor) {
        self.diskMonitor = diskMonitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        bindToDiskMonitor()
        updateStatusPresentation()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "Free space monitor")
        button.imagePosition = .imageLeft
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.toolTip = "FreeSpace Monitor"
    }

    private func bindToDiskMonitor() {
        Publishers.CombineLatest(diskMonitor.$volumes, diskMonitor.$monitoredVolumeIdentifiers)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusPresentation()
            }
            .store(in: &cancellables)
    }

    private func updateStatusPresentation() {
        guard let button = statusItem.button else { return }
        button.title = diskMonitor.summaryText()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "FreeSpace")
        menu.autoenablesItems = false

        let monitoredVolumes = diskMonitor.monitoredVolumes

        if monitoredVolumes.isEmpty {
            let noDisksItem = NSMenuItem(title: "No monitored disks", action: nil, keyEquivalent: "")
            noDisksItem.isEnabled = false
            menu.addItem(noDisksItem)
        } else {
            for volume in monitoredVolumes {
                let volumeItem = NSMenuItem(title: volume.name, action: nil, keyEquivalent: "")
                volumeItem.image = resizedIcon(from: volume.icon)
                volumeItem.toolTip = volume.accessibilityLabel

                let submenu = NSMenu(title: volume.name)
                submenu.autoenablesItems = false

                let capacityTitle = "\(volume.formattedAvailableCapacity) free of \(volume.formattedTotalCapacity)"
                let capacityItem = NSMenuItem(title: capacityTitle, action: nil, keyEquivalent: "")
                capacityItem.isEnabled = false
                submenu.addItem(capacityItem)

                if let description = volume.fileSystemDescription {
                    let descriptionItem = NSMenuItem(title: description, action: nil, keyEquivalent: "")
                    descriptionItem.isEnabled = false
                    submenu.addItem(descriptionItem)
                }

                let ejectItem = NSMenuItem(title: "Eject", action: #selector(ejectVolume(_:)), keyEquivalent: "")
                ejectItem.target = self
                ejectItem.representedObject = volume
                submenu.addItem(ejectItem)

                volumeItem.submenu = submenu
                menu.addItem(volumeItem)
            }
        }

        menu.addItem(.separator())

        let ejectAllItem = NSMenuItem(title: "Eject All", action: #selector(ejectAllVolumes), keyEquivalent: "e")
        ejectAllItem.target = self
        ejectAllItem.isEnabled = !monitoredVolumes.isEmpty
        menu.addItem(ejectAllItem)

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit FreeSpace", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            openPreferences()
            return
        }

        let menu = buildMenu()
        statusItem.popUpMenu(menu)
    }

    @objc
    private func openPreferences() {
        preferencesWindowController.show()
    }

    @objc
    private func ejectVolume(_ sender: NSMenuItem) {
        guard let volume = sender.representedObject as? VolumeInfo else { return }
        diskMonitor.eject(volume: volume)
    }

    @objc
    private func ejectAllVolumes() {
        diskMonitor.ejectAll()
    }

    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func resizedIcon(from image: NSImage) -> NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        let destinationRect = NSRect(origin: .zero, size: targetSize)
        let sourceRect = NSRect(origin: .zero, size: image.size)
        image.draw(in: destinationRect,
                   from: sourceRect,
                   operation: .sourceOver,
                   fraction: 1.0,
                   respectFlipped: true,
                   hints: nil)
        return newImage
    }
}
