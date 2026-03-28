#ifndef MEMCRUNCH_CORE_H
#define MEMCRUNCH_CORE_H

#include <stdint.h>
#include <stdbool.h>

/// Callback type for scan progress events. The JSON string is valid only during the callback.
typedef void (*ScanProgressCallback)(const char *event_json);

/// Free a string returned by any mc_* function.
void mc_free_string(char *ptr);

/// Start a directory scan. Blocks until complete.
/// Returns JSON with scan results. Caller must free with mc_free_string.
char *mc_start_scan(const char *path, ScanProgressCallback progress_cb);

/// Cancel an in-progress scan.
void mc_cancel_scan(void);

/// Get children of a node. Returns JSON array. Caller must free with mc_free_string.
char *mc_get_children(uintptr_t node_id);

/// Get a single node. Returns JSON or "null". Caller must free with mc_free_string.
char *mc_get_node(uintptr_t node_id);

/// Compute treemap layout. Returns JSON array. Caller must free with mc_free_string.
char *mc_get_treemap(uintptr_t node_id, double width, double height, uint16_t max_depth);

/// List mounted volumes. Returns JSON array. Caller must free with mc_free_string.
char *mc_list_volumes(void);

/// Get file type stats for a subtree. Returns JSON. Caller must free with mc_free_string.
char *mc_get_file_type_stats(uintptr_t node_id);

/// Check if the app has Full Disk Access.
bool mc_has_full_disk_access(void);

/// Open System Settings > Privacy > Full Disk Access.
void mc_open_full_disk_access_settings(void);

#endif /* MEMCRUNCH_CORE_H */
