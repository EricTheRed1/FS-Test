import Cocoa

struct VolumeInfo: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let fileSystemDescription: String?
    let isInternal: Bool
    let isNetwork: Bool
    let isRemovable: Bool
    let availableCapacity: Int64
    let totalCapacity: Int64
    let icon: NSImage

    init(url: URL,
         resourceValues: URLResourceValues,
         availableCapacity: Int64,
         totalCapacity: Int64) {
        self.id = url
        self.url = url
        self.name = resourceValues.volumeName ?? url.lastPathComponent
        self.fileSystemDescription = resourceValues.volumeLocalizedFormatDescription
        self.isInternal = resourceValues.volumeIsInternal ?? false
        self.isNetwork = resourceValues.volumeIsNetwork ?? false
        self.isRemovable = resourceValues.volumeIsRemovable ?? false
        self.availableCapacity = availableCapacity
        self.totalCapacity = totalCapacity
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }

    var formattedAvailableCapacity: String {
        Formatter.byteCount.string(fromByteCount: availableCapacity)
    }

    var formattedTotalCapacity: String {
        Formatter.byteCount.string(fromByteCount: totalCapacity)
    }

    var accessibilityLabel: String {
        "\(name) has \(formattedAvailableCapacity) free of \(formattedTotalCapacity)"
    }
}

private enum Formatter {
    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()
}
