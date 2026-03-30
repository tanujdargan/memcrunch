import SwiftUI

struct TreeSidebar: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedNodeId },
            set: { newValue in
                if let id = newValue {
                    viewModel.selectNode(id)
                }
            }
        )) {
            if let rootId = viewModel.rootNodeId {
                let children = viewModel.getChildren(for: rootId)
                ForEach(children) { node in
                    TreeNodeRow(node: node, viewModel: viewModel, depth: 0)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct TreeNodeRow: View {
    let node: FileNodeDTO
    @Bindable var viewModel: ScanViewModel
    let depth: Int

    @State private var isExpanded = false

    private var totalSize: UInt64 {
        viewModel.rootNodeId.flatMap { id in
            RustBridge.shared.getNode(nodeId: id)?.size
        } ?? viewModel.totalSize
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if isExpanded && node.is_dir {
                let children = viewModel.getChildren(for: node.id)
                ForEach(children) { child in
                    TreeNodeRow(node: child, viewModel: viewModel, depth: depth + 1)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: node.is_dir ? "folder.fill" : fileIcon)
                    .foregroundStyle(node.is_dir ? .blue : .secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(node.name)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 6) {
                        Text(FormatHelpers.formatSize(node.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        if totalSize > 0 {
                            // Percentage bar
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(.blue.opacity(0.3))
                                    .frame(
                                        width: geo.size.width * min(1.0, Double(node.size) / Double(totalSize)),
                                        height: 3
                                    )
                            }
                            .frame(height: 3)
                            .frame(maxWidth: 60)

                            Text(FormatHelpers.formatPercentage(node.size, of: totalSize))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if node.is_dir {
                    viewModel.drillDown(into: node.id)
                }
            }
            .onTapGesture(count: 1) {
                viewModel.selectNode(node.id)
            }
        }
        .tag(node.id)
    }

    private var fileIcon: String {
        guard let ext = node.extension_ else { return "doc" }
        switch ext {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "flac", "m4a": return "music.note"
        case "zip", "tar", "gz", "rar": return "archivebox"
        case "rs", "swift", "ts", "js", "py": return "chevron.left.forwardslash.chevron.right"
        case "app": return "app"
        default: return "doc"
        }
    }
}
