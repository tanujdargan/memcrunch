use serde::Serialize;
use std::process::Command;

#[derive(Debug, Clone, Serialize)]
pub struct VolumeInfo {
    pub name: String,
    pub mount_point: String,
    pub total_bytes: u64,
    pub available_bytes: u64,
    pub used_bytes: u64,
    pub filesystem: String,
    pub kind: VolumeKind,
    pub is_removable: bool,
    pub is_read_only: bool,
}

#[derive(Debug, Clone, Serialize)]
pub enum VolumeKind {
    Internal,
    External,
    Network,
    DiskImage,
    Unknown,
}

/// Mount points that should never appear in the volume selector.
/// These are macOS internal APFS sub-volumes, virtual filesystems,
/// and snapshot mounts whose content is already visible via firmlinks.
fn should_hide(mount_point: &str, filesystem: &str) -> bool {
    // Hide APFS internal sub-volumes
    if mount_point.starts_with("/System/Volumes/") {
        return true;
    }
    // Hide virtual/pseudo filesystems
    if mount_point == "/dev"
        || filesystem == "devfs"
        || filesystem == "autofs"
        || filesystem == "nullfs"
    {
        return true;
    }
    // Hide iOS simulator volumes
    if mount_point.contains("CoreSimulator") {
        return true;
    }
    false
}

pub fn list_volumes() -> Vec<VolumeInfo> {
    // sysinfo::Disks misses network mounts (SMB/NFS). Parse df output instead,
    // which sees everything the kernel has mounted.
    let mut volumes = Vec::new();

    // `df -Pkl` gives POSIX output: Filesystem 1024-blocks Used Available Capacity Mounted-on
    // -P = POSIX format, -k = 1024-byte blocks. NO -l flag (that hides network mounts)
    let Ok(output) = Command::new("df").args(["-Pk"]).output() else {
        return volumes;
    };
    let Ok(stdout) = String::from_utf8(output.stdout) else {
        return volumes;
    };

    // Also get filesystem types from `mount` since df doesn't show them
    let fs_types = parse_mount_fs_types();

    for line in stdout.lines().skip(1) {
        // df columns can have multi-word device names (e.g. "map auto_home").
        // Parse from the RIGHT: mount point is the last token starting with "/",
        // and the 3 numeric columns + capacity% are just before it.
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 6 {
            continue;
        }

        // Find the mount point: last column(s) that form a path starting with "/"
        // In POSIX df, Capacity% is always like "42%" and mount follows it.
        let pct_idx = cols.iter().rposition(|c| c.ends_with('%'));
        let Some(pct_idx) = pct_idx else { continue };
        if pct_idx + 1 >= cols.len() { continue; }

        let mount_point = cols[pct_idx + 1..].join(" ");
        let device = cols[..pct_idx.saturating_sub(3)].join(" ");

        // The 3 numeric columns are right before the percentage
        let available_kb: u64 = if pct_idx >= 1 { cols[pct_idx - 1].parse().unwrap_or(0) } else { 0 };
        let _used_kb: u64 = if pct_idx >= 2 { cols[pct_idx - 2].parse().unwrap_or(0) } else { 0 };
        let total_kb: u64 = if pct_idx >= 3 { cols[pct_idx - 3].parse().unwrap_or(0) } else { 0 };

        let filesystem = fs_types
            .get(mount_point.as_str())
            .cloned()
            .unwrap_or_default();

        if should_hide(&mount_point, &filesystem) {
            continue;
        }

        let total = total_kb * 1024;
        let available = available_kb * 1024;
        // Use total - available (not the df "Used" column) because on APFS
        // the "Used" column shows per-volume usage, while total/available
        // are shared across the container. total - available = actual disk consumption.
        let used = total.saturating_sub(available);

        let kind = classify_volume(&filesystem, &mount_point, &device);
        let name = volume_name(&mount_point, &device);

        volumes.push(VolumeInfo {
            name,
            mount_point,
            total_bytes: total,
            available_bytes: available,
            used_bytes: used,
            filesystem,
            kind,
            is_removable: false,
            is_read_only: false,
        });
    }

    // Sort: Internal first, then External, then Network
    volumes.sort_by_key(|v| match v.kind {
        VolumeKind::Internal => 0,
        VolumeKind::External => 1,
        VolumeKind::Network => 2,
        VolumeKind::DiskImage => 3,
        VolumeKind::Unknown => 4,
    });

    volumes
}

/// Parse `mount` output to get filesystem types for each mount point.
fn parse_mount_fs_types() -> std::collections::HashMap<String, String> {
    let mut map = std::collections::HashMap::new();
    let Ok(output) = Command::new("mount").output() else {
        return map;
    };
    let Ok(stdout) = String::from_utf8(output.stdout) else {
        return map;
    };

    for line in stdout.lines() {
        // Format: <device> on <mount_point> (<fstype>, <options>...)
        if let Some(on_idx) = line.find(" on ") {
            let rest = &line[on_idx + 4..];
            if let Some(paren_idx) = rest.find(" (") {
                let mount_point = &rest[..paren_idx];
                let opts = &rest[paren_idx + 2..];
                let fstype = opts.split(',').next().unwrap_or("").trim();
                let fstype = fstype.trim_end_matches(')');
                map.insert(mount_point.to_string(), fstype.to_string());
            }
        }
    }
    map
}

fn classify_volume(filesystem: &str, mount_point: &str, device: &str) -> VolumeKind {
    let fs_lower = filesystem.to_lowercase();

    // Network filesystems
    if fs_lower.contains("smbfs")
        || fs_lower.contains("nfs")
        || fs_lower.contains("afpfs")
        || fs_lower.contains("webdav")
        || fs_lower.contains("cifs")
        || device.starts_with("//")
    {
        return VolumeKind::Network;
    }

    // Disk images
    if mount_point.contains(".dmg") || mount_point.contains(".sparsebundle") {
        return VolumeKind::DiskImage;
    }

    // Root volume is internal
    if mount_point == "/" {
        return VolumeKind::Internal;
    }

    // Other /Volumes/ mounts are external
    if mount_point.starts_with("/Volumes/") {
        return VolumeKind::External;
    }

    VolumeKind::Unknown
}

fn volume_name(mount_point: &str, device: &str) -> String {
    if mount_point == "/" {
        return "Macintosh HD".to_string();
    }
    // Use the last path component as the display name
    std::path::Path::new(mount_point)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| device.to_string())
}
