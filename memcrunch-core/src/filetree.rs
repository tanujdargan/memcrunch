use indextree::{Arena, NodeId};
use serde::Serialize;
use std::num::NonZeroUsize;
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct FileNode {
    pub name: String,
    pub size: u64,
    pub is_dir: bool,
    pub extension: Option<String>,
    pub children_count: u32,
    pub depth: u16,
}

#[derive(Debug, Clone, Serialize)]
pub struct FileNodeDTO {
    pub id: usize,
    pub parent_id: Option<usize>,
    pub name: String,
    pub size: u64,
    pub is_dir: bool,
    pub extension: Option<String>,
    pub children_count: u32,
    pub depth: u16,
}

pub struct FileTree {
    pub arena: Arena<FileNode>,
    pub root: NodeId,
    pub total_size: u64,
    pub total_files: u64,
    pub total_dirs: u64,
    pub scan_path: PathBuf,
}

impl FileTree {
    pub fn new(root_path: PathBuf) -> Self {
        let mut arena = Arena::new();
        let root_name = root_path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| root_path.to_string_lossy().to_string());

        let root = arena.new_node(FileNode {
            name: root_name,
            size: 0,
            is_dir: true,
            extension: None,
            children_count: 0,
            depth: 0,
        });

        Self {
            arena,
            root,
            total_size: 0,
            total_files: 0,
            total_dirs: 1,
            scan_path: root_path,
        }
    }

    pub fn insert(&mut self, parent: NodeId, node: FileNode) -> NodeId {
        let id = self.arena.new_node(node);
        parent.append(id, &mut self.arena);

        if let Some(parent_data) = self.arena.get_mut(parent) {
            parent_data.get_mut().children_count += 1;
        }
        id
    }

    /// Walk the tree bottom-up and compute directory sizes from their children.
    pub fn compute_sizes(&mut self) {
        // Collect all node IDs in post-order (children before parents)
        let all_nodes: Vec<NodeId> = self
            .root
            .descendants(&self.arena)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect();

        let mut total_size = 0u64;
        let mut total_files = 0u64;
        let mut total_dirs = 0u64;

        for node_id in &all_nodes {
            let is_dir = self.arena[*node_id].get().is_dir;

            if is_dir {
                total_dirs += 1;
                // Sum sizes of direct children
                let child_sum: u64 = node_id
                    .children(&self.arena)
                    .map(|c| self.arena[c].get().size)
                    .sum();
                self.arena[*node_id].get_mut().size = child_sum;
            } else {
                total_files += 1;
                total_size += self.arena[*node_id].get().size;
            }
        }

        self.total_size = total_size;
        self.total_files = total_files;
        self.total_dirs = total_dirs;
    }

    pub fn children_of(&self, node_id: NodeId) -> Vec<FileNodeDTO> {
        let mut children: Vec<FileNodeDTO> = node_id
            .children(&self.arena)
            .map(|child_id| self.node_to_dto(child_id))
            .collect();

        // Sort by size descending (directories first, then by size)
        children.sort_by(|a, b| b.size.cmp(&a.size));
        children
    }

    pub fn node_to_dto(&self, node_id: NodeId) -> FileNodeDTO {
        let node = self.arena[node_id].get();
        let parent_id = node_id
            .parent(&self.arena)
            .map(|p| usize::from(p));

        FileNodeDTO {
            id: usize::from(node_id),
            parent_id,
            name: node.name.clone(),
            size: node.size,
            is_dir: node.is_dir,
            extension: node.extension.clone(),
            children_count: node.children_count,
            depth: node.depth,
        }
    }

    pub fn node_id_from_raw(&self, raw: usize) -> Option<NodeId> {
        let nz = NonZeroUsize::new(raw)?;
        self.arena.get_node_id_at(nz)
    }
}
