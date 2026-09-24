//! Local SQLite store for Where (spec §20, §24).
//!
//! The local database is the primary source of truth. Full-text search uses
//! SQLite FTS5, kept in sync with the `objects` table by triggers.

pub mod export;
mod schema;

use std::path::Path;

use chrono::{DateTime, Utc};
use rusqlite::{params, Connection, OptionalExtension, Row};
use serde_json::Value;
use where_core::{
    new_id, now, Direction, NewObject, Object, ObjectKind, Properties, Related, Relation,
    RelationKind,
};

pub use rusqlite;

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error(transparent)]
    Sqlite(#[from] rusqlite::Error),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
    #[error(transparent)]
    Core(#[from] where_core::CoreError),
    #[error(transparent)]
    Timestamp(#[from] chrono::ParseError),
    #[error("object not found: {0}")]
    NotFound(String),
    #[error("\"{query}\" matches {count} objects; use an id instead")]
    Ambiguous { query: String, count: usize },
    #[error("invalid input: {0}")]
    Invalid(String),
}

pub type Result<T> = std::result::Result<T, StorageError>;

/// Property keys that are never added to the full-text index.
const UNSEARCHABLE_PROPS: &[&str] = &["hash", "size", "created", "modified", "mime"];

pub struct Store {
    conn: Connection,
}

#[derive(Debug, Clone, Default, serde::Serialize)]
pub struct Stats {
    pub objects: u64,
    pub relations: u64,
    pub by_kind: Vec<(String, u64)>,
    pub index_roots: u64,
}

impl Store {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        if let Some(parent) = path.as_ref().parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)
                    .map_err(|e| StorageError::Invalid(format!("cannot create {parent:?}: {e}")))?;
            }
        }
        Self::init(Connection::open(path)?)
    }

    pub fn open_in_memory() -> Result<Self> {
        Self::init(Connection::open_in_memory()?)
    }

    fn init(conn: Connection) -> Result<Self> {
        conn.pragma_update(None, "foreign_keys", "ON")?;
        // WAL is unsupported for in-memory DBs; ignore the result there.
        let _ = conn.pragma_update(None, "journal_mode", "WAL");
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        let mut store = Store { conn };
        store.migrate()?;
        Ok(store)
    }

    fn migrate(&mut self) -> Result<()> {
        let version: i64 = self
            .conn
            .pragma_query_value(None, "user_version", |r| r.get(0))?;
        for (i, sql) in schema::MIGRATIONS.iter().enumerate().skip(version as usize) {
            let tx = self.conn.transaction()?;
            tx.execute_batch(sql)?;
            tx.pragma_update(None, "user_version", (i + 1) as i64)?;
            tx.commit()?;
        }
        Ok(())
    }

    pub fn schema_version(&self) -> Result<i64> {
        Ok(self
            .conn
            .pragma_query_value(None, "user_version", |r| r.get(0))?)
    }

    /// Direct access for advanced callers (e.g. export, tests).
    pub fn connection(&self) -> &Connection {
        &self.conn
    }

    /// Run `f` inside a single transaction (used by the indexer for speed).
    pub fn in_transaction<T>(&mut self, f: impl FnOnce(&Store) -> Result<T>) -> Result<T> {
        self.conn.execute_batch("BEGIN")?;
        match f(self) {
            Ok(v) => {
                self.conn.execute_batch("COMMIT")?;
                Ok(v)
            }
            Err(e) => {
                let _ = self.conn.execute_batch("ROLLBACK");
                Err(e)
            }
        }
    }

    // ---------------------------------------------------------------- objects

    pub fn create(&self, new: NewObject) -> Result<Object> {
        let kind = new
            .kind
            .ok_or_else(|| StorageError::Invalid("object kind is required".into()))?;
        let title = new.title.trim().to_string();
        if title.is_empty() {
            return Err(StorageError::Invalid("title must not be empty".into()));
        }
        let ts = now();
        let obj = Object {
            id: new_id(),
            kind,
            title,
            body: new.body,
            properties: new.properties,
            source_key: new.source_key,
            created_at: ts,
            updated_at: ts,
        };
        self.conn.execute(
            "INSERT INTO objects (id, kind, title, body, properties, search_extra, source_key, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                obj.id,
                obj.kind.as_str(),
                obj.title,
                obj.body,
                serde_json::to_string(&obj.properties)?,
                search_extra(&obj.properties),
                obj.source_key,
                obj.created_at.to_rfc3339(),
                obj.updated_at.to_rfc3339(),
            ],
        )?;
        Ok(obj)
    }

    /// Insert or update an object identified by `source_key`.
    /// Returns the object and whether it was newly created.
    pub fn upsert_by_source_key(&self, new: NewObject) -> Result<(Object, bool)> {
        let key = new
            .source_key
            .clone()
            .ok_or_else(|| StorageError::Invalid("source_key is required for upsert".into()))?;
        match self.get_by_source_key(&key)? {
            None => Ok((self.create(new)?, true)),
            Some(mut existing) => {
                existing.title = new.title;
                existing.body = new.body;
                existing.properties = new.properties;
                if let Some(kind) = new.kind {
                    existing.kind = kind;
                }
                self.save(&mut existing)?;
                Ok((existing, false))
            }
        }
    }

    /// Persist changes to an existing object, bumping `updated_at`.
    pub fn save(&self, obj: &mut Object) -> Result<()> {
        obj.updated_at = now();
        let n = self.conn.execute(
            "UPDATE objects SET kind=?2, title=?3, body=?4, properties=?5, search_extra=?6, updated_at=?7
             WHERE id=?1",
            params![
                obj.id,
                obj.kind.as_str(),
                obj.title,
                obj.body,
                serde_json::to_string(&obj.properties)?,
                search_extra(&obj.properties),
                obj.updated_at.to_rfc3339(),
            ],
        )?;
        if n == 0 {
            return Err(StorageError::NotFound(obj.id.clone()));
        }
        Ok(())
    }

    pub fn set_property(&self, id: &str, key: &str, value: Value) -> Result<Object> {
        let mut obj = self.get(id)?;
        obj.properties.insert(key.to_string(), value);
        self.save(&mut obj)?;
        Ok(obj)
    }

    pub fn get(&self, id: &str) -> Result<Object> {
        self.conn
            .query_row(
                &format!("{SELECT_OBJECT} WHERE id = ?1"),
                [id],
                row_to_object,
            )
            .optional()?
            .ok_or_else(|| StorageError::NotFound(id.to_string()))
    }

    pub fn get_by_source_key(&self, key: &str) -> Result<Option<Object>> {
        Ok(self
            .conn
            .query_row(
                &format!("{SELECT_OBJECT} WHERE source_key = ?1"),
                [key],
                row_to_object,
            )
            .optional()?)
    }

    /// Resolve a user-supplied reference: exact id, id prefix (≥ 6 chars),
    /// or case-insensitive exact title, optionally restricted to a kind.
    pub fn resolve(&self, reference: &str, kind: Option<ObjectKind>) -> Result<Object> {
        let reference = reference.trim();
        if let Ok(obj) = self.get(reference) {
            return Ok(obj);
        }
        let kind_str = kind.map(|k| k.as_str().to_string());
        let mut candidates: Vec<Object> = Vec::new();
        if reference.len() >= 6 {
            let mut stmt = self.conn.prepare(&format!(
                "{SELECT_OBJECT} WHERE id LIKE ?1 || '%' AND (?2 IS NULL OR kind = ?2) LIMIT 5"
            ))?;
            candidates = stmt
                .query_map(params![reference, kind_str], row_to_object)?
                .collect::<rusqlite::Result<_>>()?;
        }
        if candidates.is_empty() {
            let mut stmt = self.conn.prepare(&format!(
                "{SELECT_OBJECT} WHERE title = ?1 COLLATE NOCASE AND (?2 IS NULL OR kind = ?2) LIMIT 5"
            ))?;
            candidates = stmt
                .query_map(params![reference, kind_str], row_to_object)?
                .collect::<rusqlite::Result<_>>()?;
        }
        match candidates.len() {
            0 => Err(StorageError::NotFound(reference.to_string())),
            1 => Ok(candidates.remove(0)),
            count => Err(StorageError::Ambiguous {
                query: reference.to_string(),
                count,
            }),
        }
    }

    pub fn list(&self, kind: Option<ObjectKind>, limit: usize) -> Result<Vec<Object>> {
        let mut stmt = self.conn.prepare(&format!(
            "{SELECT_OBJECT} WHERE (?1 IS NULL OR kind = ?1) ORDER BY updated_at DESC LIMIT ?2"
        ))?;
        let rows = stmt
            .query_map(
                params![kind.map(|k| k.as_str()), limit as i64],
                row_to_object,
            )?
            .collect::<rusqlite::Result<_>>()?;
        Ok(rows)
    }

    pub fn delete(&self, id: &str) -> Result<()> {
        let n = self
            .conn
            .execute("DELETE FROM objects WHERE id = ?1", [id])?;
        if n == 0 {
            return Err(StorageError::NotFound(id.to_string()));
        }
        Ok(())
    }

    // -------------------------------------------------------------- relations

    /// Connect two objects. Idempotent.
    pub fn relate(&self, from_id: &str, kind: RelationKind, to_id: &str) -> Result<()> {
        if from_id == to_id {
            return Err(StorageError::Invalid(
                "an object cannot relate to itself".into(),
            ));
        }
        self.conn.execute(
            "INSERT OR IGNORE INTO relations (from_id, kind, to_id, created_at) VALUES (?1, ?2, ?3, ?4)",
            params![from_id, kind.as_str(), to_id, now().to_rfc3339()],
        )?;
        Ok(())
    }

    pub fn unrelate(&self, from_id: &str, kind: RelationKind, to_id: &str) -> Result<bool> {
        Ok(self.conn.execute(
            "DELETE FROM relations WHERE from_id = ?1 AND kind = ?2 AND to_id = ?3",
            params![from_id, kind.as_str(), to_id],
        )? > 0)
    }

    /// All objects related to `id`, in both directions.
    pub fn related(&self, id: &str) -> Result<Vec<Related>> {
        let sql = format!(
            "SELECT r.kind, 'out', {cols} FROM relations r JOIN objects o ON o.id = r.to_id WHERE r.from_id = ?1
             UNION ALL
             SELECT r.kind, 'in', {cols} FROM relations r JOIN objects o ON o.id = r.from_id WHERE r.to_id = ?1",
            cols = OBJECT_COLUMNS_O
        );
        let mut stmt = self.conn.prepare(&sql)?;
        let mut out = Vec::new();
        let mut rows = stmt.query([id])?;
        while let Some(row) = rows.next()? {
            let kind: String = row.get(0)?;
            let dir: String = row.get(1)?;
            out.push(Related {
                kind: kind.parse()?,
                direction: if dir == "out" {
                    Direction::Outgoing
                } else {
                    Direction::Incoming
                },
                object: object_from_row(row, 2)?,
            });
        }
        out.sort_by(|a, b| {
            (
                a.direction as u8,
                a.object.kind.display_rank(),
                &a.object.title,
            )
                .cmp(&(
                    b.direction as u8,
                    b.object.kind.display_rank(),
                    &b.object.title,
                ))
        });
        Ok(out)
    }

    /// Objects that contain `id` (e.g. the project a task belongs to).
    pub fn containers_of(&self, id: &str) -> Result<Vec<Object>> {
        let mut stmt = self.conn.prepare(&format!(
            "SELECT {OBJECT_COLUMNS_O} FROM relations r JOIN objects o ON o.id = r.from_id
             WHERE r.to_id = ?1 AND r.kind = 'contains'"
        ))?;
        let rows = stmt
            .query_map([id], |r| object_from_row(r, 0))?
            .collect::<rusqlite::Result<_>>()?;
        Ok(rows)
    }

    pub fn all_relations(&self) -> Result<Vec<Relation>> {
        let mut stmt = self.conn.prepare(
            "SELECT from_id, kind, to_id, created_at FROM relations ORDER BY created_at",
        )?;
        let mut out = Vec::new();
        let mut rows = stmt.query([])?;
        while let Some(row) = rows.next()? {
            let kind: String = row.get(1)?;
            out.push(Relation {
                from_id: row.get(0)?,
                kind: kind.parse()?,
                to_id: row.get(2)?,
                created_at: parse_ts(&row.get::<_, String>(3)?)?,
            });
        }
        Ok(out)
    }

    pub fn all_objects(&self) -> Result<Vec<Object>> {
        let mut stmt = self
            .conn
            .prepare(&format!("{SELECT_OBJECT} ORDER BY created_at"))?;
        let rows = stmt
            .query_map([], row_to_object)?
            .collect::<rusqlite::Result<_>>()?;
        Ok(rows)
    }

    // ----------------------------------------------------------------- search

    /// Raw FTS5 query. `fts_query` must already be valid FTS5 syntax —
    /// callers should build it with `where_search`, not from user input.
    /// Returns objects with a relevance score (higher is better).
    pub fn search_fts(
        &self,
        fts_query: &str,
        kinds: &[ObjectKind],
        limit: usize,
    ) -> Result<Vec<(Object, f64)>> {
        let kinds_json =
            serde_json::to_string(&kinds.iter().map(|k| k.as_str()).collect::<Vec<_>>())?;
        let sql = format!(
            "SELECT {OBJECT_COLUMNS_O}, -bm25(objects_fts, 10.0, 1.0, 3.0) AS score
             FROM objects_fts f JOIN objects o ON o.rowid = f.rowid
             WHERE objects_fts MATCH ?1
               AND (json_array_length(?2) = 0 OR o.kind IN (SELECT value FROM json_each(?2)))
             ORDER BY score DESC LIMIT ?3"
        );
        let mut stmt = self.conn.prepare(&sql)?;
        let rows = stmt
            .query_map(params![fts_query, kinds_json, limit as i64], |r| {
                Ok((
                    object_from_row(r, 0)?,
                    r.get::<_, f64>(OBJECT_COLUMN_COUNT)?,
                ))
            })?
            .collect::<rusqlite::Result<_>>()?;
        Ok(rows)
    }

    // ------------------------------------------------------------ index roots

    pub fn register_index_root(&self, path: &str, folder_id: &str) -> Result<()> {
        self.conn.execute(
            "INSERT INTO index_roots (path, folder_id, last_indexed_at) VALUES (?1, ?2, ?3)
             ON CONFLICT(path) DO UPDATE SET folder_id = excluded.folder_id, last_indexed_at = excluded.last_indexed_at",
            params![path, folder_id, now().to_rfc3339()],
        )?;
        Ok(())
    }

    pub fn index_roots(&self) -> Result<Vec<(String, String)>> {
        let mut stmt = self
            .conn
            .prepare("SELECT path, folder_id FROM index_roots ORDER BY path")?;
        let rows = stmt
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<_>>()?;
        Ok(rows)
    }

    /// Source keys under a prefix (used to detect deleted files on re-index).
    pub fn source_keys_with_prefix(&self, prefix: &str) -> Result<Vec<(String, String)>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, source_key FROM objects WHERE substr(source_key, 1, length(?1)) = ?1",
        )?;
        let rows = stmt
            .query_map([prefix], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<_>>()?;
        Ok(rows)
    }

    pub fn stats(&self) -> Result<Stats> {
        let objects: u64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM objects", [], |r| r.get(0))?;
        let relations: u64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM relations", [], |r| r.get(0))?;
        let index_roots: u64 =
            self.conn
                .query_row("SELECT COUNT(*) FROM index_roots", [], |r| r.get(0))?;
        let mut stmt = self
            .conn
            .prepare("SELECT kind, COUNT(*) FROM objects GROUP BY kind ORDER BY 2 DESC")?;
        let by_kind = stmt
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
            .collect::<rusqlite::Result<_>>()?;
        Ok(Stats {
            objects,
            relations,
            by_kind,
            index_roots,
        })
    }
}

// ------------------------------------------------------------------- helpers

const OBJECT_COLUMN_COUNT: usize = 8;
const OBJECT_COLUMNS_O: &str =
    "o.id, o.kind, o.title, o.body, o.properties, o.source_key, o.created_at, o.updated_at";
const SELECT_OBJECT: &str =
    "SELECT id, kind, title, body, properties, source_key, created_at, updated_at FROM objects";

fn row_to_object(row: &Row<'_>) -> rusqlite::Result<Object> {
    object_from_row(row, 0)
}

fn object_from_row(row: &Row<'_>, offset: usize) -> rusqlite::Result<Object> {
    let conv = |i: usize, e: Box<dyn std::error::Error + Send + Sync>| {
        rusqlite::Error::FromSqlConversionFailure(offset + i, rusqlite::types::Type::Text, e)
    };
    let kind: String = row.get(offset + 1)?;
    let props: String = row.get(offset + 4)?;
    let created: String = row.get(offset + 6)?;
    let updated: String = row.get(offset + 7)?;
    Ok(Object {
        id: row.get(offset)?,
        kind: kind.parse().map_err(|e| conv(1, Box::new(e)))?,
        title: row.get(offset + 2)?,
        body: row.get(offset + 3)?,
        properties: serde_json::from_str::<Properties>(&props).map_err(|e| conv(4, Box::new(e)))?,
        source_key: row.get(offset + 5)?,
        created_at: parse_ts(&created).map_err(|e| conv(6, Box::new(e)))?,
        updated_at: parse_ts(&updated).map_err(|e| conv(7, Box::new(e)))?,
    })
}

fn parse_ts(s: &str) -> std::result::Result<DateTime<Utc>, chrono::ParseError> {
    Ok(DateTime::parse_from_rfc3339(s)?.with_timezone(&Utc))
}

/// Text from properties that should be findable (paths, tags, URLs, emails…).
fn search_extra(props: &Properties) -> String {
    let mut parts = Vec::new();
    for (k, v) in props {
        if UNSEARCHABLE_PROPS.contains(&k.as_str()) {
            continue;
        }
        match v {
            Value::String(s) => parts.push(s.clone()),
            Value::Array(items) => {
                parts.extend(items.iter().filter_map(|i| i.as_str().map(str::to_string)))
            }
            _ => {}
        }
    }
    parts.join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn store() -> Store {
        Store::open_in_memory().unwrap()
    }

    #[test]
    fn migrates_once() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("where.db");
        Store::open(&path).unwrap();
        let s = Store::open(&path).unwrap();
        assert_eq!(s.schema_version().unwrap(), schema::MIGRATIONS.len() as i64);
    }

    #[test]
    fn create_get_update_delete() {
        let s = store();
        let mut t = s
            .create(NewObject::new(ObjectKind::Task, "Fix authentication").prop("status", "todo"))
            .unwrap();
        assert_eq!(s.get(&t.id).unwrap().title, "Fix authentication");
        t.title = "Fix Firebase authentication".into();
        s.save(&mut t).unwrap();
        assert_eq!(s.get(&t.id).unwrap().title, "Fix Firebase authentication");
        s.delete(&t.id).unwrap();
        assert!(matches!(s.get(&t.id), Err(StorageError::NotFound(_))));
    }

    #[test]
    fn rejects_empty_title() {
        assert!(store()
            .create(NewObject::new(ObjectKind::Note, "  "))
            .is_err());
    }

    #[test]
    fn resolve_by_title_prefix_and_ambiguity() {
        let s = store();
        let p = s
            .create(NewObject::new(ObjectKind::Project, "Website"))
            .unwrap();
        assert_eq!(s.resolve("website", None).unwrap().id, p.id);
        assert_eq!(s.resolve(&p.id[..8], None).unwrap().id, p.id);
        s.create(NewObject::new(ObjectKind::Note, "Website"))
            .unwrap();
        assert!(matches!(
            s.resolve("Website", None),
            Err(StorageError::Ambiguous { .. })
        ));
        assert_eq!(
            s.resolve("Website", Some(ObjectKind::Project)).unwrap().id,
            p.id
        );
    }

    #[test]
    fn relations_both_directions_and_cascade() {
        let s = store();
        let p = s
            .create(NewObject::new(ObjectKind::Project, "Website"))
            .unwrap();
        let t = s
            .create(NewObject::new(ObjectKind::Task, "Update homepage"))
            .unwrap();
        s.relate(&p.id, RelationKind::Contains, &t.id).unwrap();
        s.relate(&p.id, RelationKind::Contains, &t.id).unwrap(); // idempotent
        let from_task = s.related(&t.id).unwrap();
        assert_eq!(from_task.len(), 1);
        assert_eq!(from_task[0].label(), "part of");
        assert_eq!(s.containers_of(&t.id).unwrap()[0].id, p.id);
        s.delete(&p.id).unwrap();
        assert!(s.related(&t.id).unwrap().is_empty());
    }

    #[test]
    fn fts_tracks_updates() {
        let s = store();
        let mut n = s
            .create(NewObject::new(ObjectKind::Note, "Monitoring ideas"))
            .unwrap();
        assert_eq!(s.search_fts("\"monitor\"*", &[], 10).unwrap().len(), 1);
        n.title = "Dashboard ideas".into();
        s.save(&mut n).unwrap();
        assert!(s.search_fts("\"monitor\"*", &[], 10).unwrap().is_empty());
        assert_eq!(
            s.search_fts("\"dashboard\"", &[ObjectKind::Note], 10)
                .unwrap()
                .len(),
            1
        );
        assert!(s
            .search_fts("\"dashboard\"", &[ObjectKind::Task], 10)
            .unwrap()
            .is_empty());
    }

    #[test]
    fn properties_are_searchable_except_hash() {
        let s = store();
        s.create(
            NewObject::new(ObjectKind::File, "auth.dart")
                .prop("path", "/src/login/auth.dart")
                .prop("hash", "deadbeefcafe")
                .prop("tags", serde_json::json!(["firebase"])),
        )
        .unwrap();
        assert_eq!(s.search_fts("\"login\"", &[], 10).unwrap().len(), 1);
        assert_eq!(s.search_fts("\"firebase\"", &[], 10).unwrap().len(), 1);
        assert!(s
            .search_fts("\"deadbeefcafe\"", &[], 10)
            .unwrap()
            .is_empty());
    }

    #[test]
    fn upsert_by_source_key() {
        let s = store();
        let (a, created) = s
            .upsert_by_source_key(
                NewObject::new(ObjectKind::File, "a.txt").source_key("file:/a.txt"),
            )
            .unwrap();
        assert!(created);
        let (b, created) = s
            .upsert_by_source_key(
                NewObject::new(ObjectKind::File, "a.txt")
                    .source_key("file:/a.txt")
                    .prop("size", 3),
            )
            .unwrap();
        assert!(!created);
        assert_eq!(a.id, b.id);
        assert_eq!(s.stats().unwrap().objects, 1);
    }
}
