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

// ===========================================================================
// macOS
// ===========================================================================

#[cfg(target_os = "macos")]
fn should_hide(mount_point: &str, filesystem: &str) -> bool {
    if mount_point.starts_with("/System/Volumes/") {
        return true;
    }
    if mount_point == "/dev"
        || filesystem == "devfs"
        || filesystem == "autofs"
        || filesystem == "nullfs"
    {
        return true;
    }
    if mount_point.contains("CoreSimulator") {
        return true;
    }
    false
}

#[cfg(target_os = "macos")]
fn classify(filesystem: &str, mount_point: &str, device: &str) -> VolumeKind {
    let fs = filesystem.to_lowercase();
    if fs.contains("smbfs") || fs.contains("nfs") || fs.contains("afpfs")
        || fs.contains("webdav") || fs.contains("cifs") || device.starts_with("//")
    {
        return VolumeKind::Network;
    }
    if mount_point.contains(".dmg") || mount_point.contains(".sparsebundle") {
        return VolumeKind::DiskImage;
    }
    if mount_point == "/" {
        return VolumeKind::Internal;
    }
    if mount_point.starts_with("/Volumes/") {
        return VolumeKind::External;
    }
    VolumeKind::Unknown
}

#[cfg(target_os = "macos")]
fn volume_display_name(mount_point: &str, _device: &str) -> String {
    if mount_point == "/" {
        return "Macintosh HD".to_string();
    }
    std::path::Path::new(mount_point)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| mount_point.to_string())
}

/// Parse `mount` output to get filesystem types for each mount point (macOS/Linux).
#[cfg(unix)]
fn parse_mount_fs_types() -> std::collections::HashMap<String, String> {
    let mut map = std::collections::HashMap::new();
    let Ok(output) = Command::new("mount").output() else { return map };
    let Ok(stdout) = String::from_utf8(output.stdout) else { return map };

    for line in stdout.lines() {
        if let Some(on_idx) = line.find(" on ") {
            let rest = &line[on_idx + 4..];
            if let Some(paren_idx) = rest.find(" (") {
                let mount_point = &rest[..paren_idx];
                let opts = &rest[paren_idx + 2..];
                let fstype = opts.split(',').next().unwrap_or("").trim().trim_end_matches(')');
                map.insert(mount_point.to_string(), fstype.to_string());
            }
        }
    }
    map
}

/// List volumes using `df` — works on macOS and Linux.
#[cfg(unix)]
pub fn list_volumes() -> Vec<VolumeInfo> {
    let mut volumes = Vec::new();

    let Ok(output) = Command::new("df").args(["-Pk"]).output() else {
        return volumes;
    };
    let Ok(stdout) = String::from_utf8(output.stdout) else {
        return volumes;
    };

    let fs_types = parse_mount_fs_types();

    for line in stdout.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 6 {
            continue;
        }

        // Parse from the right: find the % column, mount point is after it.
        let pct_idx = cols.iter().rposition(|c| c.ends_with('%'));
        let Some(pct_idx) = pct_idx else { continue };
        if pct_idx + 1 >= cols.len() { continue }

        let mount_point = cols[pct_idx + 1..].join(" ");
        let device = cols[..pct_idx.saturating_sub(3)].join(" ");
        let available_kb: u64 = if pct_idx >= 1 { cols[pct_idx - 1].parse().unwrap_or(0) } else { 0 };
        let total_kb: u64 = if pct_idx >= 3 { cols[pct_idx - 3].parse().unwrap_or(0) } else { 0 };

        let filesystem = fs_types.get(mount_point.as_str()).cloned().unwrap_or_default();

        #[cfg(target_os = "macos")]
        {
            if should_hide(&mount_point, &filesystem) { continue; }
        }
        #[cfg(target_os = "linux")]
        {
            if should_hide_linux(&mount_point, &filesystem) { continue; }
        }

        let total = total_kb * 1024;
        let available = available_kb * 1024;
        let used = total.saturating_sub(available);

        #[cfg(target_os = "macos")]
        let kind = classify(&filesystem, &mount_point, &device);
        #[cfg(target_os = "linux")]
        let kind = classify_linux(&filesystem, &mount_point);

        #[cfg(target_os = "macos")]
        let name = volume_display_name(&mount_point, &device);
        #[cfg(target_os = "linux")]
        let name = volume_display_name_linux(&mount_point);

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

    volumes.sort_by_key(|v| match v.kind {
        VolumeKind::Internal => 0,
        VolumeKind::External => 1,
        VolumeKind::Network => 2,
        VolumeKind::DiskImage => 3,
        VolumeKind::Unknown => 4,
    });

    volumes
}

// ===========================================================================
// Linux
// ===========================================================================

#[cfg(target_os = "linux")]
fn should_hide_linux(mount_point: &str, filesystem: &str) -> bool {
    let virtual_fs = [
        "proc", "sysfs", "devtmpfs", "devpts", "tmpfs", "securityfs",
        "cgroup", "cgroup2", "pstore", "debugfs", "hugetlbfs", "mqueue",
        "fusectl", "configfs", "binfmt_misc", "autofs", "efivarfs",
        "bpf", "tracefs", "fuse.snapfuse", "squashfs",
    ];
    if virtual_fs.iter().any(|v| filesystem == *v) {
        return true;
    }
    let skip_paths = ["/proc", "/sys", "/dev", "/run", "/snap"];
    if skip_paths.iter().any(|p| mount_point.starts_with(p)) {
        return true;
    }
    false
}

#[cfg(target_os = "linux")]
fn classify_linux(filesystem: &str, mount_point: &str) -> VolumeKind {
    let fs = filesystem.to_lowercase();
    if fs.contains("nfs") || fs.contains("cifs") || fs.contains("smbfs") || fs.contains("fuse.sshfs") {
        return VolumeKind::Network;
    }
    if mount_point == "/" {
        return VolumeKind::Internal;
    }
    if mount_point.starts_with("/media/") || mount_point.starts_with("/mnt/") {
        return VolumeKind::External;
    }
    VolumeKind::Unknown
}

#[cfg(target_os = "linux")]
fn volume_display_name_linux(mount_point: &str) -> String {
    if mount_point == "/" {
        return "Root".to_string();
    }
    std::path::Path::new(mount_point)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| mount_point.to_string())
}

// ===========================================================================
// Windows
// ===========================================================================

#[cfg(target_os = "windows")]
pub fn list_volumes() -> Vec<VolumeInfo> {
    let mut volumes = Vec::new();

    // Use PowerShell to enumerate volumes as JSON
    let Ok(output) = Command::new("powershell")
        .args([
            "-NoProfile", "-Command",
            "Get-PSDrive -PSProvider FileSystem | Select-Object Name,Used,Free,Root | ConvertTo-Json"
        ])
        .output()
    else {
        return volumes;
    };
    let Ok(stdout) = String::from_utf8(output.stdout) else {
        return volumes;
    };

    // Parse JSON array (or single object)
    let json: serde_json::Value = match serde_json::from_str(&stdout) {
        Ok(v) => v,
        Err(_) => return volumes,
    };

    let drives = if json.is_array() {
        json.as_array().unwrap().clone()
    } else {
        vec![json]
    };

    for drive in drives {
        let name = drive["Name"].as_str().unwrap_or("").to_string();
        let root = drive["Root"].as_str().unwrap_or("").to_string();
        let used = drive["Used"].as_u64().unwrap_or(0);
        let free = drive["Free"].as_u64().unwrap_or(0);
        let total = used + free;

        if root.is_empty() || total == 0 {
            continue;
        }

        // Determine kind via WMI DriveType (2=removable, 3=fixed, 4=network)
        let kind = detect_windows_drive_kind(&root);

        volumes.push(VolumeInfo {
            name: format!("{} ({})", name, root.trim_end_matches('\\')),
            mount_point: root,
            total_bytes: total,
            available_bytes: free,
            used_bytes: used,
            filesystem: String::new(),
            kind,
            is_removable: false,
            is_read_only: false,
        });
    }

    volumes.sort_by_key(|v| match v.kind {
        VolumeKind::Internal => 0,
        VolumeKind::External => 1,
        VolumeKind::Network => 2,
        VolumeKind::DiskImage => 3,
        VolumeKind::Unknown => 4,
    });

    volumes
}

#[cfg(target_os = "windows")]
fn detect_windows_drive_kind(root: &str) -> VolumeKind {
    // Query WMI for DriveType
    let drive_letter = root.chars().next().unwrap_or('C');
    let query = format!(
        "Get-WmiObject Win32_LogicalDisk -Filter \"DeviceID='{drive_letter}:'\" | Select-Object -ExpandProperty DriveType"
    );
    let Ok(output) = Command::new("powershell")
        .args(["-NoProfile", "-Command", &query])
        .output()
    else {
        return VolumeKind::Unknown;
    };
    let Ok(stdout) = String::from_utf8(output.stdout) else {
        return VolumeKind::Unknown;
    };

    match stdout.trim() {
        "2" => VolumeKind::External,   // Removable
        "3" => VolumeKind::Internal,   // Fixed
        "4" => VolumeKind::Network,    // Network
        "5" => VolumeKind::DiskImage,  // CD-ROM / disc
        _ => VolumeKind::Unknown,
    }
}
