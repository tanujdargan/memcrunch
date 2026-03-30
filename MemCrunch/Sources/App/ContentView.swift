import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
        } detail: {
            detailContent
        }
        .toolbar {
            toolbarContent
        }
        .onAppear {
            viewModel.loadVolumes()
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        if viewModel.scanComplete {
            TreeSidebar(viewModel: viewModel)
        } else if viewModel.isScanning {
            ScanProgressView(viewModel: viewModel)
        } else {
            VolumeSelector(viewModel: viewModel)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if viewModel.scanComplete {
            HSplitView {
                TreemapView(viewModel: viewModel)
                    .frame(minWidth: 400)

                FileTypePanel(viewModel: viewModel)
                    .frame(width: 260)
            }
        } else if viewModel.isScanning {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning...")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(viewModel.currentPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Select a volume to scan")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Choose a disk from the sidebar to analyze its contents")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading: back + up buttons only
        ToolbarItemGroup(placement: .navigation) {
            if viewModel.scanComplete || viewModel.isScanning {
                Button {
                    if viewModel.isScanning { viewModel.cancelScan() }
                    viewModel.goBackToVolumes()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .help("Back to volume list")
            }

            if viewModel.scanComplete && viewModel.navigationPath.count > 1 {
                Button {
                    viewModel.navigateUp()
                } label: {
                    Label("Up", systemImage: "list.bullet.indent")
                }
                .help("Navigate to parent folder")
                .keyboardShortcut(.delete, modifiers: [])
            }
        }

        // Trailing: path pill + stats pill + cancel
        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.scanComplete {
                // Path pill — full path in a glass capsule
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.currentFullPath)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())

                // Stats pill
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(FormatHelpers.formatSize(viewModel.totalSize))
                        .fontWeight(.medium)
                    Text("in")
                        .foregroundStyle(.tertiary)
                    Text("\(FormatHelpers.formatNumber(viewModel.totalFiles)) files")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }

            if viewModel.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("\(FormatHelpers.formatNumber(viewModel.filesScanned)) files scanned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())

                Button(role: .cancel) {
                    viewModel.cancelScan()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
            }
        }
    }
}
