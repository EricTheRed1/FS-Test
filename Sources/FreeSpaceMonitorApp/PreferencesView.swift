import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var diskMonitor: DiskMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monitored Disks")
                .font(.headline)

            List {
                ForEach(diskMonitor.volumes) { volume in
                    Toggle(isOn: binding(for: volume)) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(nsImage: volume.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(volume.name)
                                    .font(.body)
                                Text("\(volume.formattedAvailableCapacity) free of \(volume.formattedTotalCapacity)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)

            Text("Right-click the menu bar icon to open these preferences.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(minWidth: 320, minHeight: 320)
    }

    private func binding(for volume: VolumeInfo) -> Binding<Bool> {
        Binding(get: {
            diskMonitor.isMonitored(volume)
        }, set: { newValue in
            diskMonitor.setMonitoring(newValue, for: volume)
        })
    }
}
