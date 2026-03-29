import Foundation
import CMemCrunchCore

// MARK: - Swift models matching Rust JSON output

struct FileNodeDTO: Codable, Identifiable, Hashable {
    let id: Int
    let parent_id: Int?
    let name: String
    let size: UInt64
    let is_dir: Bool
    let extension_: String?
    let children_count: UInt32
    let depth: UInt16

    enum CodingKeys: String, CodingKey {
        case id, parent_id, name, size, is_dir
        case extension_ = "extension"
        case children_count, depth
    }
}

struct TreemapRect: Codable, Identifiable {
    let id: Int
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let name: String
    let size: UInt64
    let is_dir: Bool
    let extension_: String?
    let color: String

    enum CodingKeys: String, CodingKey {
        case id, x, y, w, h, name, size, is_dir
        case extension_ = "extension"
        case color
    }
}

struct VolumeInfo: Codable, Identifiable, Hashable {
    var id: String { mount_point }
    let name: String
    let mount_point: String
    let total_bytes: UInt64
    let available_bytes: UInt64
    let used_bytes: UInt64
    let filesystem: String
    let kind: String
    let is_removable: Bool
    let is_read_only: Bool
}

struct FileTypeStats: Codable {
    let extension_: String
    let category: String
    let count: UInt64
    let total_size: UInt64
    let percentage: Double

    enum CodingKeys: String, CodingKey {
        case extension_ = "extension"
        case category, count, total_size, percentage
    }
}

struct CategoryStats: Codable, Identifiable {
    var id: String { category }
    let category: String
    let count: UInt64
    let total_size: UInt64
    let percentage: Double
    let color: String
    let top_extensions: [FileTypeStats]
}

struct FileTypeStatsResponse: Codable {
    let categories: [CategoryStats]
    let total_size: UInt64
    let total_files: UInt64
}

struct ScanResult: Codable {
    let ok: Bool
    let root_id: Int?
    let total_size: UInt64?
    let total_files: UInt64?
    let total_dirs: UInt64?
    let error: String?
}

struct ScanProgressEvent: Codable {
    let files_scanned: UInt64
    let dirs_scanned: UInt64
    let bytes_scanned: UInt64
    let current_path: String
}

struct ScanCompleteEvent: Codable {
    let total_size: UInt64
    let total_files: UInt64
    let total_dirs: UInt64
    let elapsed_ms: UInt64
}

// MARK: - Bridge to Rust FFI

@MainActor
final class RustBridge {
    static let shared = RustBridge()
    private let decoder = JSONDecoder()

    private init() {}

    // Helper: read C string, free it, decode JSON
    private func decodeAndFree<T: Decodable>(_ ptr: UnsafeMutablePointer<CChar>?, as type: T.Type) -> T? {
        guard let ptr else { return nil }
        let str = String(cString: ptr)
        mc_free_string(ptr)
        return try? decoder.decode(T.self, from: Data(str.utf8))
    }

    private func stringAndFree(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
        guard let ptr else { return "" }
        let str = String(cString: ptr)
        mc_free_string(ptr)
        return str
    }

    // MARK: - Scan

    func startScan(path: String, onProgress: @escaping (String) -> Void) async -> ScanResult? {
        let pathC = path.withCString { strdup($0) }!

        let callback: @convention(c) (UnsafePointer<CChar>?) -> Void = { jsonPtr in
            guard let jsonPtr else { return }
            let json = String(cString: jsonPtr)
            // Post to main thread via notification
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .scanProgress,
                    object: nil,
                    userInfo: ["json": json]
                )
            }
        }

        // Run scan on background thread
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let resultPtr = mc_start_scan(pathC, callback)
                free(pathC)

                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                let result: ScanResult? = {
                    guard let resultPtr else { return nil }
                    let str = String(cString: resultPtr)
                    mc_free_string(resultPtr)
                    return try? self.decoder.decode(ScanResult.self, from: Data(str.utf8))
                }()

                continuation.resume(returning: result)
            }
        }
    }

    func cancelScan() {
        mc_cancel_scan()
    }

    // MARK: - Tree queries

    func getChildren(nodeId: Int) -> [FileNodeDTO] {
        let ptr = mc_get_children(UInt(nodeId))
        return decodeAndFree(ptr, as: [FileNodeDTO].self) ?? []
    }

    func getNode(nodeId: Int) -> FileNodeDTO? {
        let ptr = mc_get_node(UInt(nodeId))
        return decodeAndFree(ptr, as: FileNodeDTO.self)
    }

    // MARK: - Treemap

    func getTreemap(nodeId: Int, width: Double, height: Double, maxDepth: UInt16 = 3) -> [TreemapRect] {
        let ptr = mc_get_treemap(UInt(nodeId), width, height, maxDepth)
        return decodeAndFree(ptr, as: [TreemapRect].self) ?? []
    }

    // MARK: - Volumes

    func listVolumes() -> [VolumeInfo] {
        let ptr = mc_list_volumes()
        return decodeAndFree(ptr, as: [VolumeInfo].self) ?? []
    }

    // MARK: - File types

    func getFileTypeStats(nodeId: Int) -> FileTypeStatsResponse? {
        let ptr = mc_get_file_type_stats(UInt(nodeId))
        return decodeAndFree(ptr, as: FileTypeStatsResponse.self)
    }

    // MARK: - Permissions

    nonisolated func hasFullDiskAccess() -> Bool {
        mc_has_full_disk_access()
    }

    nonisolated func openFullDiskAccessSettings() {
        mc_open_full_disk_access_settings()
    }
}

extension Notification.Name {
    static let scanProgress = Notification.Name("scanProgress")
}
