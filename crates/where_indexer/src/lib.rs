//! Folder indexing (spec §13).
//!
//! Indexing is opt-in: only folders the user explicitly selects are walked.
//! Each file becomes a `File` object (or `Image`/`Video` by MIME type) with
//! path, filename, extension, size, dates, BLAKE3 hash and MIME type. The
//! selected root becomes a `Folder` object that `contains` every file.
//!
//! Re-indexing is incremental: unchanged files (same size + mtime) are not
//! re-hashed, and files that disappeared from disk are removed from Where.
//! Where never modifies or deletes the user's files (spec §40).

use std::collections::HashSet;
use std::fs::{self, File};
use std::io::{self, Read};
use std::path::Path;

use chrono::{DateTime, Utc};
use serde::Serialize;
use walkdir::{DirEntry, WalkDir};
use where_core::{NewObject, Object, ObjectKind, RelationKind};
use where_storage::{Result, StorageError, Store};

/// Directory names skipped by default. Hidden entries (dot-files) are skipped too.
pub const DEFAULT_EXCLUDES: &[&str] = &[
    "node_modules",
    "target",
    "build",
    "dist",
    ".git",
    "__pycache__",
    ".dart_tool",
    "Pods",
];

#[derive(Debug, Clone)]
pub struct IndexOptions {
    pub excludes: Vec<String>,
    pub include_hidden: bool,
    /// Files larger than this are indexed without a hash.
    pub max_hash_bytes: u64,
    /// Optionally attach the indexed folder to a project.
    pub project_id: Option<String>,
}

impl Default for IndexOptions {
    fn default() -> Self {
        Self {
            excludes: DEFAULT_EXCLUDES.iter().map(|s| s.to_string()).collect(),
            include_hidden: false,
            max_hash_bytes: 512 * 1024 * 1024,
            project_id: None,
        }
    }
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct IndexReport {
    pub root: String,
    pub folder_id: String,
    pub scanned: u64,
    pub added: u64,
    pub updated: u64,
    pub unchanged: u64,
    pub removed: u64,
    pub skipped: Vec<String>,
}

pub fn source_key(path: &Path) -> String {
    format!("file:{}", path.to_string_lossy())
}

pub fn index_folder(
    store: &mut Store,
    root: impl AsRef<Path>,
    opts: &IndexOptions,
) -> Result<IndexReport> {
    let root = fs::canonicalize(root.as_ref())
        .map_err(|e| StorageError::Invalid(format!("cannot open {:?}: {e}", root.as_ref())))?;
    if !root.is_dir() {
        return Err(StorageError::Invalid(format!("{root:?} is not a folder")));
    }

    store.in_transaction(|store| {
        let folder_name = root
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| root.to_string_lossy().into_owned());
        let (folder, _) = store.upsert_by_source_key(
            NewObject::new(ObjectKind::Folder, folder_name)
                .prop("path", root.to_string_lossy().as_ref())
                .source_key(format!("folder:{}", root.to_string_lossy())),
        )?;
        if let Some(project_id) = &opts.project_id {
            store.relate(project_id, RelationKind::Contains, &folder.id)?;
        }

        let mut report = IndexReport {
            root: root.to_string_lossy().into_owned(),
            folder_id: folder.id.clone(),
            ..Default::default()
        };
        let mut seen: HashSet<String> = HashSet::new();

        let walker = WalkDir::new(&root)
            .follow_links(false)
            .into_iter()
            .filter_entry(|e| e.depth() == 0 || !is_excluded(e, opts));

        for entry in walker {
            let entry = match entry {
                Ok(e) => e,
                Err(e) => {
                    report.skipped.push(e.to_string());
                    continue;
                }
            };
            if !entry.file_type().is_file() {
                continue;
            }
            report.scanned += 1;
            let key = source_key(entry.path());
            seen.insert(key.clone());
            match index_file(store, entry.path(), &key, opts) {
                Ok((obj, outcome)) => {
                    match outcome {
                        Outcome::Added => report.added += 1,
                        Outcome::Updated => report.updated += 1,
                        Outcome::Unchanged => report.unchanged += 1,
                    }
                    store.relate(&folder.id, RelationKind::Contains, &obj.id)?;
                }
                Err(e) => report
                    .skipped
                    .push(format!("{}: {e}", entry.path().display())),
            }
        }

        // Remove objects for files that no longer exist under this root.
        let mut prefix = source_key(&root);
        if !prefix.ends_with(std::path::MAIN_SEPARATOR) {
            prefix.push(std::path::MAIN_SEPARATOR);
        }
        for (id, key) in store.source_keys_with_prefix(&prefix)? {
            if !seen.contains(&key) {
                store.delete(&id)?;
                report.removed += 1;
            }
        }

        store.register_index_root(&report.root, &folder.id)?;
        Ok(report)
    })
}

/// Re-index every previously registered root.
pub fn reindex_all(store: &mut Store, opts: &IndexOptions) -> Result<Vec<IndexReport>> {
    let roots = store.index_roots()?;
    let mut reports = Vec::new();
    for (path, _) in roots {
        if Path::new(&path).is_dir() {
            reports.push(index_folder(store, &path, opts)?);
        }
    }
    Ok(reports)
}

enum Outcome {
    Added,
    Updated,
    Unchanged,
}

fn index_file(
    store: &Store,
    path: &Path,
    key: &str,
    opts: &IndexOptions,
) -> Result<(Object, Outcome)> {
    let io = |e: io::Error| StorageError::Invalid(e.to_string());
    let meta = fs::metadata(path).map_err(io)?;
    let size = meta.len();
    let modified = meta
        .modified()
        .ok()
        .map(|t| DateTime::<Utc>::from(t).to_rfc3339());
    let created = meta
        .created()
        .ok()
        .map(|t| DateTime::<Utc>::from(t).to_rfc3339());

    let existing = store.get_by_source_key(key)?;
    if let Some(obj) = &existing {
        let same_size = obj.properties.get("size").and_then(|v| v.as_u64()) == Some(size);
        let same_mtime = obj.prop_str("modified") == modified.as_deref();
        if same_size && same_mtime {
            return Ok((obj.clone(), Outcome::Unchanged));
        }
    }

    let filename = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    let extension = path
        .extension()
        .map(|e| e.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    let mime = mime_guess::from_path(path).first_or_octet_stream();
    let kind = match mime.type_() {
        mime_guess::mime::IMAGE => ObjectKind::Image,
        mime_guess::mime::VIDEO => ObjectKind::Video,
        _ => ObjectKind::File,
    };

    let mut new = NewObject::new(kind, filename.clone())
        .prop("path", path.to_string_lossy().as_ref())
        .prop("filename", filename)
        .prop("size", size)
        .prop("mime", mime.essence_str())
        .source_key(key);
    if !extension.is_empty() {
        new = new.prop("extension", extension);
    }
    if let Some(m) = modified {
        new = new.prop("modified", m);
    }
    if let Some(c) = created {
        new = new.prop("created", c);
    }
    if size <= opts.max_hash_bytes {
        new = new.prop("hash", format!("blake3:{}", hash_file(path).map_err(io)?));
    }

    let (obj, created) = store.upsert_by_source_key(new)?;
    Ok((
        obj,
        if created {
            Outcome::Added
        } else {
            Outcome::Updated
        },
    ))
}

fn is_excluded(entry: &DirEntry, opts: &IndexOptions) -> bool {
    let name = entry.file_name().to_string_lossy();
    (!opts.include_hidden && name.starts_with('.'))
        || (entry.file_type().is_dir() && opts.excludes.iter().any(|x| x == &*name))
}

fn hash_file(path: &Path) -> io::Result<String> {
    let mut hasher = blake3::Hasher::new();
    let mut file = File::open(path)?;
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hasher.finalize().to_hex().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn tree() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path();
        fs::create_dir_all(p.join("docs")).unwrap();
        fs::create_dir_all(p.join("node_modules/pkg")).unwrap();
        fs::create_dir_all(p.join(".secret")).unwrap();
        fs::write(p.join("docs/network-design.pdf"), b"%PDF-1.7 fake").unwrap();
        fs::write(p.join("auth.dart"), b"void main() {}").unwrap();
        fs::write(p.join("logo.png"), b"\x89PNG").unwrap();
        fs::write(p.join("node_modules/pkg/index.js"), b"x").unwrap();
        fs::write(p.join(".secret/key.txt"), b"x").unwrap();
        dir
    }

    #[test]
    fn indexes_with_metadata_and_excludes() {
        let dir = tree();
        let mut store = Store::open_in_memory().unwrap();
        let r = index_folder(&mut store, dir.path(), &IndexOptions::default()).unwrap();
        assert_eq!((r.scanned, r.added), (3, 3), "{r:?}");

        let pdf = store
            .get_by_source_key(&source_key(
                &fs::canonicalize(dir.path())
                    .unwrap()
                    .join("docs/network-design.pdf"),
            ))
            .unwrap()
            .unwrap();
        assert_eq!(pdf.kind, ObjectKind::File);
        assert_eq!(pdf.prop_str("extension"), Some("pdf"));
        assert_eq!(pdf.prop_str("mime"), Some("application/pdf"));
        assert!(pdf.prop_str("hash").unwrap().starts_with("blake3:"));
        assert_eq!(
            store.containers_of(&pdf.id).unwrap()[0].kind,
            ObjectKind::Folder
        );

        let hits = where_search::search(&store, "network", Default::default()).unwrap();
        assert!(hits
            .hits
            .iter()
            .any(|h| h.object.title == "network-design.pdf"));
        let images = where_search::search(&store, "kind:image", Default::default()).unwrap();
        assert_eq!(images.hits.len(), 1);
    }

    #[test]
    fn reindex_is_incremental_and_removes_deleted() {
        let dir = tree();
        let mut store = Store::open_in_memory().unwrap();
        index_folder(&mut store, dir.path(), &IndexOptions::default()).unwrap();

        let r = index_folder(&mut store, dir.path(), &IndexOptions::default()).unwrap();
        assert_eq!((r.added, r.updated, r.unchanged, r.removed), (0, 0, 3, 0));

        fs::remove_file(dir.path().join("logo.png")).unwrap();
        fs::write(dir.path().join("auth.dart"), b"void main() { login(); }").unwrap();
        let r = reindex_all(&mut store, &IndexOptions::default())
            .unwrap()
            .remove(0);
        assert_eq!((r.added, r.updated, r.removed), (0, 1, 1), "{r:?}");
        // root folder + 2 files
        assert_eq!(store.stats().unwrap().objects, 3);
    }

    #[test]
    fn attaches_to_project() {
        let dir = tree();
        let mut store = Store::open_in_memory().unwrap();
        let p = store
            .create(NewObject::new(ObjectKind::Project, "Website"))
            .unwrap();
        let opts = IndexOptions {
            project_id: Some(p.id.clone()),
            ..Default::default()
        };
        let r = index_folder(&mut store, dir.path(), &opts).unwrap();
        assert_eq!(store.containers_of(&r.folder_id).unwrap()[0].id, p.id);
    }

    #[test]
    fn rejects_non_folder() {
        let dir = tree();
        let mut store = Store::open_in_memory().unwrap();
        assert!(index_folder(
            &mut store,
            dir.path().join("auth.dart"),
            &IndexOptions::default()
        )
        .is_err());
    }
}
