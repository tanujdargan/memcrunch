import Foundation
import SwiftUI

@MainActor
@Observable
final class ScanViewModel {
    // MARK: - State

    var volumes: [VolumeInfo] = []
    var selectedVolume: VolumeInfo?
    var isScanning = false
    var scanComplete = false
    var rootNodeId: Int?
    var selectedNodeId: Int?
    var navigationPath: [Int] = []

    // Scan progress
    var filesScanned: UInt64 = 0
    var dirsScanned: UInt64 = 0
    var bytesScanned: UInt64 = 0
    var currentPath: String = ""
    var scanStartTime: Date?
    var totalSize: UInt64 = 0
    var totalFiles: UInt64 = 0
    var totalDirs: UInt64 = 0
    var elapsedMs: UInt64 = 0
    var scanningVolumeTotal: UInt64 = 0 // Total bytes on volume being scanned

    // Data
    var rootChildren: [FileNodeDTO] = []
    var treemapRects: [TreemapRect] = []
    var fileTypeStats: FileTypeStatsResponse?
    var expandedNodes: Set<Int> = []
    var childrenCache: [Int: [FileNodeDTO]] = [:]

    // Full disk access
    var hasFullDiskAccess = false

    private let bridge = RustBridge.shared
    private nonisolated(unsafe) var progressObserver: Any?

    // MARK: - Lifecycle

    init() {
        setupProgressObserver()
        loadVolumes()
        checkFullDiskAccess()
    }

    deinit {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupProgressObserver() {
        progressObserver = NotificationCenter.default.addObserver(
            forName: .scanProgress,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let json = notification.userInfo?["json"] as? String else { return }
            Task { @MainActor in
                self?.handleProgressJSON(json)
            }
        }
    }

    // MARK: - Volumes

    func loadVolumes() {
        volumes = bridge.listVolumes()
    }

    func checkFullDiskAccess() {
        hasFullDiskAccess = bridge.hasFullDiskAccess()
    }

    func openFullDiskAccessSettings() {
        bridge.openFullDiskAccessSettings()
    }

    // MARK: - Scanning

    func startScan(path: String) {
        guard !isScanning else { return }

        isScanning = true
        scanComplete = false
        rootNodeId = nil
        selectedNodeId = nil
        navigationPath = []
        filesScanned = 0
        dirsScanned = 0
        bytesScanned = 0
        currentPath = ""
        scanStartTime = Date()
        rootChildren = []
        treemapRects = []
        fileTypeStats = nil
        expandedNodes = []
        childrenCache = [:]

        Task {
            let result = await bridge.startScan(path: path) { [weak self] _ in
                // Progress handled via notification
            }

            isScanning = false

            if let result, result.ok {
                scanComplete = true
                rootNodeId = result.root_id
                totalSize = result.total_size ?? 0
                totalFiles = result.total_files ?? 0
                totalDirs = result.total_dirs ?? 0

                if let rootId = result.root_id {
                    selectedNodeId = rootId
                    navigationPath = [rootId]
                    loadChildren(for: rootId)
                }
            }
        }
    }

    func cancelScan() {
        bridge.cancelScan()
    }

    func goBackToVolumes() {
        scanComplete = false
        isScanning = false
        rootNodeId = nil
        selectedNodeId = nil
        navigationPath = []
        rootChildren = []
        treemapRects = []
        fileTypeStats = nil
        expandedNodes = []
        childrenCache = [:]
        selectedVolume = nil
        loadVolumes()
    }

    func scanVolume(_ volume: VolumeInfo) {
        selectedVolume = volume
        scanningVolumeTotal = volume.used_bytes
        startScan(path: volume.mount_point)
    }

    // MARK: - Tree navigation

    func loadChildren(for nodeId: Int) {
        if childrenCache[nodeId] == nil {
            childrenCache[nodeId] = bridge.getChildren(nodeId: nodeId)
        }

        if nodeId == selectedNodeId || nodeId == rootNodeId {
            rootChildren = childrenCache[nodeId] ?? []
        }
    }

    func getChildren(for nodeId: Int) -> [FileNodeDTO] {
        if childrenCache[nodeId] == nil {
            childrenCache[nodeId] = bridge.getChildren(nodeId: nodeId)
        }
        return childrenCache[nodeId] ?? []
    }

    func selectNode(_ nodeId: Int) {
        selectedNodeId = nodeId
        loadChildren(for: nodeId)
        updateFileTypeStats()
    }

    func drillDown(into nodeId: Int) {
        navigationPath.append(nodeId)
        selectNode(nodeId)
    }

    func navigateUp() {
        guard navigationPath.count > 1 else { return }
        navigationPath.removeLast()
        if let last = navigationPath.last {
            selectNode(last)
        }
    }

    func navigateTo(index: Int) {
        guard index < navigationPath.count else { return }
        navigationPath = Array(navigationPath.prefix(index + 1))
        if let last = navigationPath.last {
            selectNode(last)
        }
    }

    // MARK: - Path

    /// Full path built from the navigation stack node names.
    var currentFullPath: String {
        guard !navigationPath.isEmpty else { return "" }
        let names = navigationPath.map { id in
            bridge.getNode(nodeId: id)?.name ?? "?"
        }
        // First node is the scan root (e.g. "/" or "/Volumes/8tb-old")
        let root = selectedVolume?.mount_point ?? names.first ?? "/"
        if names.count <= 1 { return root }
        let sub = names.dropFirst().joined(separator: "/")
        if root.hasSuffix("/") {
            return root + sub
        }
        return root + "/" + sub
    }

    // MARK: - Treemap

    func updateTreemap(width: Double, height: Double) {
        guard let nodeId = selectedNodeId, width > 0, height > 0 else {
            treemapRects = []
            return
        }
        treemapRects = bridge.getTreemap(nodeId: nodeId, width: width, height: height)
    }

    // MARK: - File type stats

    func updateFileTypeStats() {
        guard let nodeId = selectedNodeId else {
            fileTypeStats = nil
            return
        }
        fileTypeStats = bridge.getFileTypeStats(nodeId: nodeId)
    }

    // MARK: - Progress handling

    private func handleProgressJSON(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }

        // Try to parse the tagged enum format
        struct TaggedEvent: Codable {
            let event: String
            let data: AnyCodable
        }

        // Simple approach: try each event type
        if json.contains("\"Progress\"") {
            struct ProgressWrapper: Codable {
                let data: ScanProgressEvent
            }
            if let wrapper = try? JSONDecoder().decode(ProgressWrapper.self, from: data) {
                filesScanned = wrapper.data.files_scanned
                dirsScanned = wrapper.data.dirs_scanned
                bytesScanned = wrapper.data.bytes_scanned
                currentPath = wrapper.data.current_path
            }
        } else if json.contains("\"Complete\"") {
            struct CompleteWrapper: Codable {
                let data: ScanCompleteEvent
            }
            if let wrapper = try? JSONDecoder().decode(CompleteWrapper.self, from: data) {
                totalSize = wrapper.data.total_size
                totalFiles = wrapper.data.total_files
                totalDirs = wrapper.data.total_dirs
                elapsedMs = wrapper.data.elapsed_ms
            }
        }
    }
}

// Utility for untyped JSON
struct AnyCodable: Codable {
    init(from decoder: Decoder) throws {
        _ = try decoder.singleValueContainer()
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}
