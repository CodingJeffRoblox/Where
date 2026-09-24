//! Data export (spec §28). Exports preserve object relationships.

use std::fmt::Write as _;
use std::fs;
use std::path::Path;

use serde::Serialize;
use where_core::{Object, ObjectKind, Relation};

use crate::{Result, StorageError, Store};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Format {
    /// One JSON document: `{ version, exported_at, objects, relations }`.
    Json,
    /// One Markdown document grouped by kind, with relationships listed.
    Markdown,
    /// A directory with `objects.csv` and `relations.csv`.
    Csv,
    /// A standalone copy of the SQLite database.
    Sqlite,
}

impl std::str::FromStr for Format {
    type Err = String;
    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        match s.to_ascii_lowercase().as_str() {
            "json" => Ok(Format::Json),
            "md" | "markdown" => Ok(Format::Markdown),
            "csv" => Ok(Format::Csv),
            "sqlite" | "db" => Ok(Format::Sqlite),
            other => Err(format!(
                "unknown export format: {other} (json, md, csv, sqlite)"
            )),
        }
    }
}

#[derive(Serialize)]
struct JsonExport<'a> {
    format: &'static str,
    version: u32,
    exported_at: String,
    objects: &'a [Object],
    relations: &'a [Relation],
}

pub fn export(store: &Store, format: Format, out: &Path) -> Result<()> {
    let io = |e: std::io::Error| StorageError::Invalid(format!("write {out:?}: {e}"));
    match format {
        Format::Json => fs::write(out, to_json(store)?).map_err(io),
        Format::Markdown => fs::write(out, to_markdown(store)?).map_err(io),
        Format::Csv => {
            fs::create_dir_all(out).map_err(io)?;
            let (objects, relations) = to_csv(store)?;
            fs::write(out.join("objects.csv"), objects).map_err(io)?;
            fs::write(out.join("relations.csv"), relations).map_err(io)
        }
        Format::Sqlite => {
            if out.exists() {
                return Err(StorageError::Invalid(format!("{out:?} already exists")));
            }
            store
                .connection()
                .execute("VACUUM INTO ?1", [out.to_string_lossy().as_ref()])?;
            Ok(())
        }
    }
}

pub fn to_json(store: &Store) -> Result<String> {
    let objects = store.all_objects()?;
    let relations = store.all_relations()?;
    Ok(serde_json::to_string_pretty(&JsonExport {
        format: "where-export",
        version: 1,
        exported_at: where_core::now().to_rfc3339(),
        objects: &objects,
        relations: &relations,
    })?)
}

pub fn to_markdown(store: &Store) -> Result<String> {
    let mut objects = store.all_objects()?;
    objects
        .sort_by(|a, b| (a.kind.display_rank(), &a.title).cmp(&(b.kind.display_rank(), &b.title)));
    let mut md = String::from("# Where export\n");
    let mut current: Option<ObjectKind> = None;
    for obj in &objects {
        if current != Some(obj.kind) {
            current = Some(obj.kind);
            let _ = write!(md, "\n## {}\n", obj.kind.label());
        }
        let _ = write!(md, "\n### {}\n\n`{}`\n", obj.title, obj.id);
        for (k, v) in &obj.properties {
            let v = v
                .as_str()
                .map(str::to_string)
                .unwrap_or_else(|| v.to_string());
            let _ = writeln!(md, "- **{k}:** {v}");
        }
        if !obj.body.is_empty() {
            let _ = write!(md, "\n{}\n", obj.body);
        }
        let related = store.related(&obj.id)?;
        if !related.is_empty() {
            md.push('\n');
            for r in related {
                let _ = writeln!(
                    md,
                    "- {} → {} ({})",
                    r.label(),
                    r.object.title,
                    r.object.kind
                );
            }
        }
    }
    Ok(md)
}

pub fn to_csv(store: &Store) -> Result<(String, String)> {
    let mut objects =
        String::from("id,kind,title,body,properties,source_key,created_at,updated_at\n");
    for o in store.all_objects()? {
        let row = [
            o.id,
            o.kind.to_string(),
            o.title,
            o.body,
            serde_json::to_string(&o.properties)?,
            o.source_key.unwrap_or_default(),
            o.created_at.to_rfc3339(),
            o.updated_at.to_rfc3339(),
        ];
        objects.push_str(
            &row.iter()
                .map(|f| csv_field(f))
                .collect::<Vec<_>>()
                .join(","),
        );
        objects.push('\n');
    }
    let mut relations = String::from("from_id,kind,to_id,created_at\n");
    for r in store.all_relations()? {
        let _ = writeln!(
            relations,
            "{},{},{},{}",
            r.from_id,
            r.kind,
            r.to_id,
            r.created_at.to_rfc3339()
        );
    }
    Ok((objects, relations))
}

fn csv_field(s: &str) -> String {
    if s.contains([',', '"', '\n', '\r']) {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use where_core::{NewObject, RelationKind};

    fn sample() -> Store {
        let s = Store::open_in_memory().unwrap();
        let p = s
            .create(NewObject::new(ObjectKind::Project, "Website"))
            .unwrap();
        let n = s
            .create(
                NewObject::new(ObjectKind::Note, "Redesign, v2").body("Say \"hi\"\nsecond line"),
            )
            .unwrap();
        s.relate(&p.id, RelationKind::Contains, &n.id).unwrap();
        s
    }

    #[test]
    fn json_round_trips_relations() {
        let v: serde_json::Value = serde_json::from_str(&to_json(&sample()).unwrap()).unwrap();
        assert_eq!(v["objects"].as_array().unwrap().len(), 2);
        assert_eq!(v["relations"][0]["kind"], "contains");
    }

    #[test]
    fn markdown_lists_relationships() {
        let md = to_markdown(&sample()).unwrap();
        assert!(md.contains("## PROJECT"));
        assert!(md.contains("contains → Redesign, v2 (note)"));
        assert!(md.contains("part of → Website (project)"));
    }

    #[test]
    fn csv_escapes() {
        let (objects, relations) = to_csv(&sample()).unwrap();
        assert!(objects.contains("\"Redesign, v2\""));
        assert!(objects.contains("\"Say \"\"hi\"\"\nsecond line\""));
        assert_eq!(relations.lines().count(), 2);
    }

    #[test]
    fn sqlite_copy() {
        let dir = tempfile::tempdir().unwrap();
        let out = dir.path().join("copy.db");
        export(&sample(), Format::Sqlite, &out).unwrap();
        assert_eq!(Store::open(&out).unwrap().stats().unwrap().objects, 2);
    }
}
