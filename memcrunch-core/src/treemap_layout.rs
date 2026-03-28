use crate::filetype;
use crate::filetree::FileTree;
use indextree::NodeId;
use serde::Serialize;
use treemap::{MapItem, Mappable, Rect, TreemapLayout};

#[derive(Clone, Serialize)]
pub struct TreemapNode {
    pub id: usize,
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
    pub name: String,
    pub size: u64,
    pub is_dir: bool,
    pub extension: Option<String>,
    pub color: String,
}

/// Compute a flat (single-level) treemap of the direct children of `root_node`.
/// Each child gets exactly one non-overlapping rectangle.
pub fn compute_treemap(
    tree: &FileTree,
    root_node: NodeId,
    viewport_width: f64,
    viewport_height: f64,
    _max_depth: u16,
    _min_size_px: f64,
) -> Vec<TreemapNode> {
    let gap = 2.0;

    let mut children: Vec<(NodeId, &crate::filetree::FileNode)> = root_node
        .children(&tree.arena)
        .filter_map(|child_id| {
            let node = tree.arena.get(child_id)?;
            let data = node.get();
            if data.size > 0 {
                Some((child_id, data))
            } else {
                None
            }
        })
        .collect();

    if children.is_empty() {
        return Vec::new();
    }

    // Sort children by size DESCENDING — must match the treemap crate's internal
    // sort_descending so that children[i] corresponds to items[i] after layout.
    children.sort_by(|a, b| b.1.size.cmp(&a.1.size));

    let mut items: Vec<MapItem> = children
        .iter()
        .map(|(_, data)| MapItem::with_size(data.size as f64))
        .collect();

    let bounds = Rect::from_points(0.0, 0.0, viewport_width, viewport_height);
    let layout = TreemapLayout::new();
    layout.layout_items(&mut items, bounds);

    let mut result = Vec::with_capacity(items.len());

    for (i, item) in items.iter().enumerate() {
        let (child_id, child_data) = &children[i];
        let b = item.bounds();

        let x = b.x + gap;
        let y = b.y + gap;
        let w = (b.w - gap * 2.0).max(0.0);
        let h = (b.h - gap * 2.0).max(0.0);

        if w < 1.0 || h < 1.0 {
            continue;
        }

        let color = if child_data.is_dir {
            get_directory_color(tree, *child_id)
        } else {
            let ext = child_data.extension.as_deref().unwrap_or("");
            let category = filetype::categorize(ext);
            filetype::category_color(&category)
        };

        result.push(TreemapNode {
            id: usize::from(*child_id),
            x,
            y,
            w,
            h,
            name: child_data.name.clone(),
            size: child_data.size,
            is_dir: child_data.is_dir,
            extension: child_data.extension.clone(),
            color,
        });
    }

    result
}

fn get_directory_color(tree: &FileTree, dir_id: NodeId) -> String {
    let mut category_sizes: std::collections::HashMap<String, u64> =
        std::collections::HashMap::new();

    let mut count = 0;
    for desc_id in dir_id.descendants(&tree.arena) {
        let node = tree.arena[desc_id].get();
        if !node.is_dir {
            let ext = node.extension.as_deref().unwrap_or("");
            let category = filetype::categorize(ext);
            let color = filetype::category_color(&category);
            *category_sizes.entry(color).or_insert(0) += node.size;

            count += 1;
            if count >= 1000 {
                break;
            }
        }
    }

    category_sizes
        .into_iter()
        .max_by_key(|(_, size)| *size)
        .map(|(color, _)| color)
        .unwrap_or_else(|| "#6B7280".to_string())
}
