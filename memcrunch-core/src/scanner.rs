use crate::filetree::{FileNode, FileTree};
use indextree::NodeId;
use serde::Serialize;
use std::collections::{HashMap, HashSet};
use std::os::unix::fs::MetadataExt;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;

#[derive(Clone, Serialize)]
#[serde(tag = "event", content = "data")]
pub enum ScanEvent {
    Progress {
        files_scanned: u64,
        dirs_scanned: u64,
        bytes_scanned: u64,
        current_path: String,
    },
    Complete {
        total_size: u64,
        total_files: u64,
        total_dirs: u64,
        elapsed_ms: u64,
    },
    Error {
        message: String,
        path: String,
    },
}

pub struct ScanConfig {
    pub root_path: PathBuf,
    pub cancel: Arc<AtomicBool>,
}

/// Collect all active mount points from the system.
/// On macOS, this includes APFS sub-volumes like /System/Volumes/Data,
/// external drives in /Volumes/, iOS simulator volumes, etc.
/// Directories that must be skipped when scanning the root filesystem.
/// These are either:
/// - APFS sub-volume mount points (Data, VM, Preboot, etc.) whose contents
///   are already visible via firmlinks at the root level
/// - Container directories for other volumes (/Volumes contains external/network
///   drives and a symlink back to root — scanning it causes double-counting)
/// - Virtual filesystems (/dev)
const SKIP_WHEN_SCANNING_ROOT: &[&str] = &[
    "/Volumes",
    "/dev",
    "/System/Volumes/Data",
    "/System/Volumes/VM",
    "/System/Volumes/Preboot",
    "/System/Volumes/Update",
    "/System/Volumes/xarts",
    "/System/Volumes/iSCPreboot",
    "/System/Volumes/Hardware",
];

/// Build the set of paths to skip during a scan.
/// Combines static macOS paths with dynamically detected mount points.
fn build_skip_set(scan_root: &PathBuf) -> HashSet<PathBuf> {
    let mut skip = HashSet::new();

    // Always skip these when scanning root
    if scan_root.as_os_str() == "/" {
        for path in SKIP_WHEN_SCANNING_ROOT {
            skip.insert(PathBuf::from(path));
        }
    }

    // Dynamically detect all mount points from the system and skip any
    // that are WITHIN the scan root (but not the scan root itself).
    // This catches mounts the static list might miss (e.g. iOS simulator volumes,
    // loopback mounts, FUSE filesystems).
    let disks = sysinfo::Disks::new_with_refreshed_list();
    for disk in disks.list() {
        let mp = disk.mount_point().to_path_buf();
        if mp != *scan_root && mp.starts_with(scan_root) {
            skip.insert(mp);
        }
    }

    skip
}

/// Get the physical (allocated) size of a file in bytes.
/// Uses st_blocks * 512 which reflects actual disk consumption,
/// correctly handling sparse files (like Docker.raw), APFS clones,
/// and compressed files.
fn physical_size(metadata: &std::fs::Metadata) -> u64 {
    // st_blocks is in 512-byte units (even on filesystems with larger block sizes)
    metadata.blocks() * 512
}

pub fn scan_directory(
    config: ScanConfig,
    on_event: impl Fn(ScanEvent) + Send + 'static,
) -> Result<FileTree, String> {
    let start = Instant::now();
    let mut tree = FileTree::new(config.root_path.clone());

    // Build the set of paths to skip during this scan.
    let skip_mounts = Arc::new(build_skip_set(&config.root_path));
    let skip_mounts_clone = skip_mounts.clone();

    // Map from parent path to its NodeId for tree reconstruction
    let mut path_to_node: HashMap<PathBuf, NodeId> = HashMap::new();
    path_to_node.insert(config.root_path.clone(), tree.root);

    let mut files_scanned: u64 = 0;
    let mut dirs_scanned: u64 = 1; // root
    let mut bytes_scanned: u64 = 0;

    let walker = jwalk::WalkDir::new(&config.root_path)
        .sort(true)
        .skip_hidden(false)
        .process_read_dir(move |_depth, _path, _state, children| {
            children.retain(|entry| {
                let Ok(entry) = entry else { return false };

                // Skip directories that are mount points for other volumes
                if entry.file_type().is_dir() {
                    let path = entry.path();
                    if skip_mounts_clone.contains(&path) {
                        return false;
                    }
                }

                true
            });
        });

    for entry in walker {
        // Check cancellation
        if config.cancel.load(Ordering::Relaxed) {
            return Err("Scan cancelled".to_string());
        }

        let entry = match entry {
            Ok(e) => e,
            Err(e) => {
                on_event(ScanEvent::Error {
                    message: e.to_string(),
                    path: String::new(),
                });
                continue;
            }
        };

        let path = entry.path();

        // Skip the root itself (already added)
        if path == config.root_path {
            continue;
        }

        // Double-check: skip any path that is a mount point
        if skip_mounts.contains(&path) {
            continue;
        }

        let parent_path = match path.parent() {
            Some(p) => p.to_path_buf(),
            None => continue,
        };

        let parent_node = match path_to_node.get(&parent_path) {
            Some(&id) => id,
            None => continue,
        };

        let metadata = match entry.metadata() {
            Ok(m) => m,
            Err(e) => {
                on_event(ScanEvent::Error {
                    message: e.to_string(),
                    path: path.to_string_lossy().to_string(),
                });
                continue;
            }
        };

        let is_dir = metadata.is_dir();
        // Use physical (allocated) size — handles sparse files, APFS clones, compression
        let size = if is_dir { 0 } else { physical_size(&metadata) };
        let name = entry.file_name().to_string_lossy().to_string();

        let extension = if !is_dir {
            path.extension()
                .map(|e| e.to_string_lossy().to_string().to_lowercase())
        } else {
            None
        };

        let depth = entry.depth as u16;

        let node = FileNode {
            name,
            size,
            is_dir,
            extension,
            children_count: 0,
            depth,
        };

        let node_id = tree.insert(parent_node, node);

        if is_dir {
            dirs_scanned += 1;
            path_to_node.insert(path.to_path_buf(), node_id);
        } else {
            files_scanned += 1;
            bytes_scanned += size;
        }

        // Send progress every 5,000 entries
        if (files_scanned + dirs_scanned) % 5_000 == 0 {
            on_event(ScanEvent::Progress {
                files_scanned,
                dirs_scanned,
                bytes_scanned,
                current_path: path.to_string_lossy().to_string(),
            });
        }
    }

    // Compute directory sizes bottom-up
    tree.compute_sizes();

    let elapsed = start.elapsed().as_millis() as u64;

    on_event(ScanEvent::Complete {
        total_size: tree.total_size,
        total_files: tree.total_files,
        total_dirs: tree.total_dirs,
        elapsed_ms: elapsed,
    });

    Ok(tree)
}
