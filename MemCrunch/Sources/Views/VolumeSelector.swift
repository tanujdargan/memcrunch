import SwiftUI

struct VolumeSelector: View {
    @Bindable var viewModel: ScanViewModel
    @State private var selectedMountPoint: String?

    private var selectedVolume: VolumeInfo? {
        viewModel.volumes.first { $0.mount_point == selectedMountPoint }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Volumes") {
                    ForEach(viewModel.volumes) { volume in
                        VolumeRow(
                            volume: volume,
                            isSelected: selectedMountPoint == volume.mount_point
                        ) {
                            selectedMountPoint = volume.mount_point
                        }
                    }
                }

                if !viewModel.hasFullDiskAccess {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Full Disk Access", systemImage: "lock.shield")
                                .font(.headline)
                            Text("Grant Full Disk Access to scan all directories including system files.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Open Settings") {
                                viewModel.openFullDiskAccessSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.message = "Choose a directory to scan"
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.startScan(path: url.path)
                        }
                    } label: {
                        Label("Scan Custom Folder...", systemImage: "folder.badge.plus")
                    }
                }
            }
            .listStyle(.sidebar)

            // Start button pinned to bottom
            VStack(spacing: 8) {
                Divider()
                Button {
                    if let vol = selectedVolume {
                        viewModel.scanVolume(vol)
                    }
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Scan")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedVolume == nil)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            viewModel.loadVolumes()
            // Auto-select root volume
            if selectedMountPoint == nil {
                selectedMountPoint = viewModel.volumes.first?.mount_point
            }
        }
    }
}

struct VolumeRow: View {
    let volume: VolumeInfo
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Radio circle
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                    }
                }

                Image(systemName: volumeIcon)
                    .font(.title3)
                    .foregroundStyle(volumeColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(volume.name.isEmpty ? volume.mount_point : volume.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if volume.mount_point != "/" {
                        Text(volume.mount_point)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    // Usage bar
                    if volume.total_bytes > 0 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.quaternary)
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(usageColor)
                                    .frame(width: max(1, geo.size.width * usageRatio), height: 4)
                            }
                        }
                        .frame(height: 4)

                        Text("\(FormatHelpers.formatSize(volume.used_bytes)) of \(FormatHelpers.formatSize(volume.total_bytes))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var volumeIcon: String {
        switch volume.kind {
        case "Internal": return "internaldrive"
        case "External": return "externaldrive"
        case "Network": return "network"
        case "DiskImage": return "opticaldisc"
        default: return "questionmark.folder"
        }
    }

    private var volumeColor: Color {
        switch volume.kind {
        case "Internal": return .blue
        case "External": return .orange
        case "Network": return .green
        case "DiskImage": return .purple
        default: return .gray
        }
    }

    private var usageRatio: Double {
        guard volume.total_bytes > 0 else { return 0 }
        return min(1.0, Double(volume.used_bytes) / Double(volume.total_bytes))
    }

    private var usageColor: Color {
        if usageRatio > 0.9 { return .red }
        if usageRatio > 0.7 { return .orange }
        return .blue
    }
}
