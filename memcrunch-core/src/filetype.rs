use crate::filetree::FileTree;
use indextree::NodeId;
use serde::Serialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Hash, Eq, PartialEq)]
pub enum FileCategory {
    Documents,
    Images,
    Video,
    Audio,
    Code,
    Archives,
    Applications,
    System,
    Other,
}

#[derive(Clone, Serialize)]
pub struct FileTypeStats {
    pub extension: String,
    pub category: FileCategory,
    pub count: u64,
    pub total_size: u64,
    pub percentage: f64,
}

#[derive(Clone, Serialize)]
pub struct CategoryStats {
    pub category: FileCategory,
    pub count: u64,
    pub total_size: u64,
    pub percentage: f64,
    pub color: String,
    pub top_extensions: Vec<FileTypeStats>,
}

#[derive(Clone, Serialize)]
pub struct FileTypeStatsResponse {
    pub categories: Vec<CategoryStats>,
    pub total_size: u64,
    pub total_files: u64,
}

pub fn categorize(extension: &str) -> FileCategory {
    match extension {
        "pdf" | "doc" | "docx" | "txt" | "rtf" | "odt" | "xls" | "xlsx" | "csv" | "ppt"
        | "pptx" | "pages" | "numbers" | "keynote" | "md" | "epub" => FileCategory::Documents,

        "jpg" | "jpeg" | "png" | "gif" | "bmp" | "svg" | "webp" | "ico" | "tiff" | "tif"
        | "heic" | "heif" | "raw" | "cr2" | "nef" | "psd" | "ai" => FileCategory::Images,

        "mp4" | "mov" | "avi" | "mkv" | "wmv" | "flv" | "webm" | "m4v" | "mpg" | "mpeg"
        | "3gp" => FileCategory::Video,

        "mp3" | "wav" | "flac" | "aac" | "ogg" | "wma" | "m4a" | "aiff" | "alac" => {
            FileCategory::Audio
        }

        "rs" | "ts" | "tsx" | "js" | "jsx" | "py" | "go" | "java" | "c" | "cpp" | "h"
        | "hpp" | "swift" | "kt" | "rb" | "php" | "css" | "scss" | "html" | "xml" | "json"
        | "yaml" | "yml" | "toml" | "sh" | "bash" | "zsh" | "sql" | "vue" | "svelte" => {
            FileCategory::Code
        }

        "zip" | "tar" | "gz" | "bz2" | "xz" | "7z" | "rar" | "tgz" | "zst" | "lz4" => {
            FileCategory::Archives
        }

        "app" | "dmg" | "pkg" | "deb" | "rpm" | "exe" | "msi" | "apk" | "ipa" => {
            FileCategory::Applications
        }

        "dylib" | "so" | "dll" | "sys" | "kext" | "plist" | "log" | "lock" | "cache" => {
            FileCategory::System
        }

        _ => FileCategory::Other,
    }
}

pub fn category_color(category: &FileCategory) -> String {
    match category {
        FileCategory::Documents => "#3B82F6".to_string(), // Blue
        FileCategory::Images => "#22C55E".to_string(),    // Green
        FileCategory::Video => "#A855F7".to_string(),     // Purple
        FileCategory::Audio => "#F97316".to_string(),     // Orange
        FileCategory::Code => "#06B6D4".to_string(),      // Cyan
        FileCategory::Archives => "#EF4444".to_string(),  // Red
        FileCategory::Applications => "#EC4899".to_string(), // Pink
        FileCategory::System => "#6B7280".to_string(),    // Gray
        FileCategory::Other => "#9CA3AF".to_string(),     // Light gray
    }
}

pub fn compute_file_type_stats(tree: &FileTree, root_node: NodeId) -> FileTypeStatsResponse {
    let mut ext_map: HashMap<String, (FileCategory, u64, u64)> = HashMap::new();
    let mut total_size: u64 = 0;
    let mut total_files: u64 = 0;

    for node_id in root_node.descendants(&tree.arena) {
        let node = tree.arena[node_id].get();
        if node.is_dir {
            continue;
        }

        total_files += 1;
        total_size += node.size;

        let ext = node.extension.as_deref().unwrap_or("(none)");
        let category = categorize(ext);

        let entry = ext_map
            .entry(ext.to_string())
            .or_insert_with(|| (category, 0, 0));
        entry.1 += 1;
        entry.2 += node.size;
    }

    // Group by category
    let mut cat_map: HashMap<FileCategory, (u64, u64, Vec<FileTypeStats>)> = HashMap::new();

    for (ext, (category, count, size)) in &ext_map {
        let percentage = if total_size > 0 {
            (*size as f64 / total_size as f64) * 100.0
        } else {
            0.0
        };

        let stats = FileTypeStats {
            extension: ext.clone(),
            category: category.clone(),
            count: *count,
            total_size: *size,
            percentage,
        };

        let entry = cat_map
            .entry(category.clone())
            .or_insert_with(|| (0, 0, Vec::new()));
        entry.0 += count;
        entry.1 += size;
        entry.2.push(stats);
    }

    let mut categories: Vec<CategoryStats> = cat_map
        .into_iter()
        .map(|(category, (count, size, mut exts))| {
            exts.sort_by(|a, b| b.total_size.cmp(&a.total_size));
            exts.truncate(10); // Top 10 extensions per category

            let percentage = if total_size > 0 {
                (size as f64 / total_size as f64) * 100.0
            } else {
                0.0
            };

            CategoryStats {
                color: category_color(&category),
                category,
                count,
                total_size: size,
                percentage,
                top_extensions: exts,
            }
        })
        .collect();

    categories.sort_by(|a, b| b.total_size.cmp(&a.total_size));

    FileTypeStatsResponse {
        categories,
        total_size,
        total_files,
    }
}
