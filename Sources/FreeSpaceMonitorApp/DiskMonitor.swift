import Cocoa
import Combine

final class DiskMonitor: NSObject, ObservableObject {
    @Published private(set) var volumes: [VolumeInfo] = []
    @Published private(set) var monitoredVolumeIdentifiers: Set<String>

    var monitoredVolumes: [VolumeInfo] {
        volumes.filter { monitoredVolumeIdentifiers.contains($0.url.path) }
    }

    private let resourceKeys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeLocalizedNameKey,
        .volumeLocalizedFormatDescriptionKey,
        .volumeIsInternalKey,
        .volumeIsNetworkKey,
        .volumeIsRemovableKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey
    ]

    private let userDefaults = UserDefaults.standard
    private let monitoredVolumesKey = "FreeSpaceMonitor.monitoredVolumePaths"

    private var refreshTimer: Timer?

    override init() {
        let storedIdentifiers = userDefaults.array(forKey: monitoredVolumesKey) as? [String] ?? []
        self.monitoredVolumeIdentifiers = Set(storedIdentifiers)
        super.init()
        setupNotifications()
        refreshVolumes()
        startTimer()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        refreshTimer?.invalidate()
    }

    func isMonitored(_ volume: VolumeInfo) -> Bool {
        monitoredVolumeIdentifiers.contains(volume.url.path)
    }

    func setMonitoring(_ isMonitored: Bool, for volume: VolumeInfo) {
        var identifiers = monitoredVolumeIdentifiers
        if isMonitored {
            identifiers.insert(volume.url.path)
        } else {
            identifiers.remove(volume.url.path)
        }
        updateMonitoredVolumeIdentifiers(identifiers)
    }

    func eject(volume: VolumeInfo, completion: ((Bool, Error?) -> Void)? = nil) {
        NSWorkspace.shared.unmountAndEjectDevice(at: volume.url) { success, error in
            DispatchQueue.main.async {
                completion?(success, error)
            }
        }
    }

    func ejectAll(completion: (([(VolumeInfo, Bool, Error?)]) -> Void)? = nil) {
        let monitored = monitoredVolumes
        guard !monitored.isEmpty else {
            completion?([])
            return
        }

        let group = DispatchGroup()
        var results: [(VolumeInfo, Bool, Error?)] = []
        let resultsLock = NSLock()

        for volume in monitored {
            group.enter()
            eject(volume: volume) { success, error in
                resultsLock.lock()
                results.append((volume, success, error))
                resultsLock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion?(results)
        }
    }

    func refreshVolumes() {
        DispatchQueue.global(qos: .utility).async {
            let fetched = Self.fetchVolumes(resourceKeys: self.resourceKeys)
            DispatchQueue.main.async {
                self.volumes = fetched
                self.syncMonitoredIdentifiers(with: fetched)
            }
        }
    }

    func summaryText() -> String {
        guard let primaryVolume = monitoredVolumes.sorted(by: DiskMonitor.volumeSortPredicate).first else {
            return "Disks"
        }
        let available = primaryVolume.formattedAvailableCapacity
        return "\(primaryVolume.name) \(available)"
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshVolumes()
        }
        if let timer = refreshTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func setupNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self,
                           selector: #selector(handleVolumeChangeNotification(_:)),
                           name: NSWorkspace.didMountNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleVolumeChangeNotification(_:)),
                           name: NSWorkspace.didUnmountNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleVolumeChangeNotification(_:)),
                           name: NSWorkspace.didRenameVolumeNotification,
                           object: nil)
    }

    @objc
    private func handleVolumeChangeNotification(_ notification: Notification) {
        refreshVolumes()
    }

    private func updateMonitoredVolumeIdentifiers(_ newIdentifiers: Set<String>) {
        monitoredVolumeIdentifiers = newIdentifiers
        userDefaults.set(Array(newIdentifiers), forKey: monitoredVolumesKey)
        userDefaults.synchronize()
    }

    private func syncMonitoredIdentifiers(with volumes: [VolumeInfo]) {
        let availableIdentifiers = Set(volumes.map { $0.url.path })
        var identifiers = monitoredVolumeIdentifiers.intersection(availableIdentifiers)

        let newVolumes = availableIdentifiers.subtracting(monitoredVolumeIdentifiers)
        identifiers.formUnion(newVolumes)

        if identifiers.isEmpty {
            identifiers = availableIdentifiers
        }

        if identifiers != monitoredVolumeIdentifiers {
            updateMonitoredVolumeIdentifiers(identifiers)
        }
    }

    private static func fetchVolumes(resourceKeys: Set<URLResourceKey>) -> [VolumeInfo] {
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(resourceKeys),
                                                               options: [.skipHiddenVolumes]) else {
            return []
        }

        let volumes: [VolumeInfo] = urls.compactMap { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: resourceKeys)
                let totalCapacity = resourceValues.volumeTotalCapacity ?? 0
                let availableCapacity = resourceValues.volumeAvailableCapacity ??
                    resourceValues.volumeAvailableCapacityForImportantUsage ?? 0
                guard totalCapacity > 0 else { return nil }
                return VolumeInfo(url: url,
                                  resourceValues: resourceValues,
                                  availableCapacity: Int64(availableCapacity),
                                  totalCapacity: Int64(totalCapacity))
            } catch {
                return nil
            }
        }

        return volumes.sorted(by: volumeSortPredicate)
    }

    private static func volumeSortPredicate(_ lhs: VolumeInfo, _ rhs: VolumeInfo) -> Bool {
        if lhs.isInternal != rhs.isInternal {
            return lhs.isInternal && !rhs.isInternal
        }
        if lhs.isNetwork != rhs.isNetwork {
            return !lhs.isNetwork && rhs.isNetwork
        }
        if lhs.isRemovable != rhs.isRemovable {
            return !lhs.isRemovable && rhs.isRemovable
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
