use crate::filetree::FileTree;
use crate::filetype;
use crate::scanner::ScanConfig;
use crate::treemap_layout;
use crate::volumes;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

// Global state — the scan result lives here between FFI calls
static GLOBAL_STATE: std::sync::LazyLock<Mutex<Option<FileTree>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

static SCAN_CANCEL: std::sync::LazyLock<Arc<AtomicBool>> =
    std::sync::LazyLock::new(|| Arc::new(AtomicBool::new(false)));

// Helper: Rust String → heap-allocated C string (caller must free with mc_free_string)
fn to_c_string(s: &str) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

// Helper: C string → Rust &str
unsafe fn from_c_str<'a>(ptr: *const c_char) -> &'a str {
    if ptr.is_null() {
        return "";
    }
    unsafe { CStr::from_ptr(ptr) }.to_str().unwrap_or("")
}

/// Free a string returned by any mc_* function.
#[unsafe(no_mangle)]
pub extern "C" fn mc_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

/// Callback type for scan progress events.
/// The JSON string is only valid for the duration of the callback.
pub type ScanProgressCallback = extern "C" fn(event_json: *const c_char);

/// Start a directory scan. Blocks until complete.
/// Returns JSON: {"ok": true, "root_id": N, "total_size": N, "total_files": N, "total_dirs": N, "elapsed_ms": N}
/// Or on error: {"ok": false, "error": "message"}
/// The progress_cb is called periodically with ScanEvent JSON.
#[unsafe(no_mangle)]
pub extern "C" fn mc_start_scan(
    path: *const c_char,
    progress_cb: ScanProgressCallback,
) -> *mut c_char {
    let path_str = unsafe { from_c_str(path) };

    SCAN_CANCEL.store(false, Ordering::Relaxed);

    let config = ScanConfig {
        root_path: std::path::PathBuf::from(path_str),
        cancel: SCAN_CANCEL.clone(),
    };

    let result = crate::scanner::scan_directory(config, move |event| {
        if let Ok(json) = serde_json::to_string(&event) {
            if let Ok(c_json) = CString::new(json) {
                progress_cb(c_json.as_ptr());
            }
        }
    });

    match result {
        Ok(tree) => {
            let root_id = usize::from(tree.root);
            let total_size = tree.total_size;
            let total_files = tree.total_files;
            let total_dirs = tree.total_dirs;

            if let Ok(mut state) = GLOBAL_STATE.lock() {
                *state = Some(tree);
            }

            let json = format!(
                r#"{{"ok":true,"root_id":{},"total_size":{},"total_files":{},"total_dirs":{}}}"#,
                root_id, total_size, total_files, total_dirs
            );
            to_c_string(&json)
        }
        Err(e) => {
            let json = format!(r#"{{"ok":false,"error":"{}"}}"#, e.replace('"', "'"));
            to_c_string(&json)
        }
    }
}

/// Cancel an in-progress scan.
#[unsafe(no_mangle)]
pub extern "C" fn mc_cancel_scan() {
    SCAN_CANCEL.store(true, Ordering::Relaxed);
}

/// Get children of a node. Returns JSON array of FileNodeDTO.
/// Caller must free the returned string with mc_free_string.
#[unsafe(no_mangle)]
pub extern "C" fn mc_get_children(node_id: usize) -> *mut c_char {
    let state = GLOBAL_STATE.lock().unwrap();
    let tree = match state.as_ref() {
        Some(t) => t,
        None => return to_c_string("[]"),
    };

    let id = match tree.node_id_from_raw(node_id) {
        Some(id) => id,
        None => return to_c_string("[]"),
    };

    let children = tree.children_of(id);
    let json = serde_json::to_string(&children).unwrap_or_else(|_| "[]".to_string());
    to_c_string(&json)
}

/// Get a single node's info. Returns JSON FileNodeDTO or "null".
/// Caller must free the returned string with mc_free_string.
#[unsafe(no_mangle)]
pub extern "C" fn mc_get_node(node_id: usize) -> *mut c_char {
    let state = GLOBAL_STATE.lock().unwrap();
    let tree = match state.as_ref() {
        Some(t) => t,
        None => return to_c_string("null"),
    };

    let id = match tree.node_id_from_raw(node_id) {
        Some(id) => id,
        None => return to_c_string("null"),
    };

    let dto = tree.node_to_dto(id);
    let json = serde_json::to_string(&dto).unwrap_or_else(|_| "null".to_string());
    to_c_string(&json)
}

/// Compute treemap layout. Returns JSON array of TreemapNode.
/// Caller must free the returned string with mc_free_string.
#[unsafe(no_mangle)]
pub extern "C" fn mc_get_treemap(
    node_id: usize,
    width: f64,
    height: f64,
    max_depth: u16,
) -> *mut c_char {
    let state = GLOBAL_STATE.lock().unwrap();
    let tree = match state.as_ref() {
        Some(t) => t,
        None => return to_c_string("[]"),
    };

    let id = match tree.node_id_from_raw(node_id) {
        Some(id) => id,
        None => return to_c_string("[]"),
    };

    let rects = treemap_layout::compute_treemap(tree, id, width, height, max_depth, 3.0);
    let json = serde_json::to_string(&rects).unwrap_or_else(|_| "[]".to_string());
    to_c_string(&json)
}

/// List all mounted volumes. Returns JSON array of VolumeInfo.
/// Caller must free the returned string with mc_free_string.
#[unsafe(no_mangle)]
pub extern "C" fn mc_list_volumes() -> *mut c_char {
    let vols = volumes::list_volumes();
    let json = serde_json::to_string(&vols).unwrap_or_else(|_| "[]".to_string());
    to_c_string(&json)
}

/// Get file type statistics for a subtree. Returns JSON FileTypeStatsResponse.
/// Caller must free the returned string with mc_free_string.
#[unsafe(no_mangle)]
pub extern "C" fn mc_get_file_type_stats(node_id: usize) -> *mut c_char {
    let state = GLOBAL_STATE.lock().unwrap();
    let tree = match state.as_ref() {
        Some(t) => t,
        None => return to_c_string("{}"),
    };

    let id = match tree.node_id_from_raw(node_id) {
        Some(id) => id,
        None => return to_c_string("{}"),
    };

    let stats = filetype::compute_file_type_stats(tree, id);
    let json = serde_json::to_string(&stats).unwrap_or_else(|_| "{}".to_string());
    to_c_string(&json)
}

/// Check if the app has Full Disk Access.
#[unsafe(no_mangle)]
pub extern "C" fn mc_has_full_disk_access() -> bool {
    if let Some(home) = dirs::home_dir() {
        std::fs::read_dir(home.join("Library/Safari")).is_ok()
    } else {
        false
    }
}

/// Open System Settings > Privacy > Full Disk Access.
#[unsafe(no_mangle)]
pub extern "C" fn mc_open_full_disk_access_settings() {
    let _ = std::process::Command::new("open")
        .arg("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        .spawn();
}
