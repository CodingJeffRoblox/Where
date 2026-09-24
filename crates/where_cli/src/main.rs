//! `where-cli` — a thin command-line front end over the Where core.
//!
//! It exists to prove the five prototype questions in spec §38 before the
//! Flutter UI is wired up, and remains useful for scripting and debugging.

use std::path::PathBuf;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use where_core::{NewObject, Object, ObjectKind, RelationKind, TaskStatus};
use where_indexer::IndexOptions;
use where_search::{MatchReason, Options};
use where_storage::{export, Store};

#[derive(Parser)]
#[command(name = "where-cli", version, about = "Find what you're looking for.")]
struct Cli {
    /// Database file. Defaults to the platform data directory.
    #[arg(long, global = true, env = "WHERE_DB")]
    db: Option<PathBuf>,
    /// Output JSON instead of text.
    #[arg(long, global = true)]
    json: bool,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Search everything. Supports filters like `kind:task`.
    #[command(alias = "s")]
    Search {
        query: Vec<String>,
        #[arg(short, long, default_value_t = 25)]
        limit: usize,
    },
    /// Create a project, task, note, person, website, …
    #[command(alias = "new")]
    Add {
        /// Object kind (project, task, note, person, website, …).
        kind: ObjectKind,
        title: String,
        /// Longer text for notes and descriptions.
        #[arg(short, long, default_value = "")]
        body: String,
        /// Put it inside this project (id or exact title).
        #[arg(short, long)]
        project: Option<String>,
        /// Task status: todo, in_progress, done.
        #[arg(long)]
        status: Option<TaskStatus>,
        /// URL for websites, bookmarks and repositories.
        #[arg(long)]
        url: Option<String>,
        /// Tags (repeatable).
        #[arg(short, long = "tag")]
        tags: Vec<String>,
    },
    /// Connect two objects: `link <from> contains|involves|references <to>`.
    Link {
        from: String,
        relation: RelationKind,
        to: String,
    },
    /// Remove a connection between two objects.
    Unlink {
        from: String,
        relation: RelationKind,
        to: String,
    },
    /// Show an object and everything connected to it.
    Show { reference: String },
    /// List recent objects, optionally of one kind.
    List {
        kind: Option<ObjectKind>,
        #[arg(short, long, default_value_t = 25)]
        limit: usize,
    },
    /// Update a task's status.
    Status { task: String, status: TaskStatus },
    /// Delete an object from Where (never touches files on disk).
    Delete {
        reference: String,
        /// Required: destructive actions need explicit confirmation (spec §11).
        #[arg(long)]
        yes: bool,
    },
    /// Index a folder you choose. Re-run to refresh. No folder = refresh all.
    Index {
        folder: Option<PathBuf>,
        #[arg(short, long)]
        project: Option<String>,
        #[arg(long)]
        include_hidden: bool,
    },
    /// Export everything: json, md, csv (directory), sqlite.
    Export {
        #[arg(short, long, default_value = "json")]
        format: String,
        out: PathBuf,
    },
    /// What Where knows (spec §27).
    Stats,
    /// Load the "Cybersecurity Lab" example from spec §39 and search it.
    Demo,
}

fn main() {
    if let Err(e) = run(Cli::parse()) {
        eprintln!("error: {e:#}");
        std::process::exit(1);
    }
}

fn run(cli: Cli) -> Result<()> {
    let db = cli.db.clone().unwrap_or_else(default_db_path);
    let mut store = Store::open(&db).with_context(|| format!("opening {}", db.display()))?;
    let json = cli.json;

    match cli.command {
        Command::Search { query, limit } => {
            let q = query.join(" ");
            let results = where_search::search(
                &store,
                &q,
                Options {
                    limit,
                    ..Default::default()
                },
            )?;
            if json {
                return print_json(&results);
            }
            if results.hits.is_empty() {
                println!("Nothing found for \"{q}\".");
                return Ok(());
            }
            for (kind, hits) in results.grouped() {
                println!("{}", kind.label());
                for h in hits {
                    let via = match h.reason {
                        MatchReason::Direct => String::new(),
                        MatchReason::Contains => format!("  (contains {})", h.via.join(", ")),
                    };
                    println!("  {}{}  {}", h.object.title, via, short_id(&h.object));
                }
                println!();
            }
            println!(
                "{} results in {:.1} ms",
                results.hits.len(),
                results.elapsed.as_secs_f64() * 1000.0
            );
        }
        Command::Add {
            kind,
            title,
            body,
            project,
            status,
            url,
            tags,
        } => {
            let mut new = NewObject::new(kind, title).body(body);
            if kind == ObjectKind::Task {
                new = new.prop("status", status.unwrap_or(TaskStatus::Todo).as_str());
            } else if status.is_some() {
                bail!("--status only applies to tasks");
            }
            if let Some(url) = url {
                new = new.prop("url", url);
            }
            if !tags.is_empty() {
                new = new.prop("tags", tags);
            }
            let project = project
                .map(|p| store.resolve(&p, Some(ObjectKind::Project)))
                .transpose()?;
            let obj = store.create(new)?;
            if let Some(p) = &project {
                store.relate(&p.id, RelationKind::Contains, &obj.id)?;
            }
            if json {
                return print_json(&obj);
            }
            print!("Created {} \"{}\" {}", obj.kind, obj.title, short_id(&obj));
            match project {
                Some(p) => println!(" in {}", p.title),
                None => println!(),
            }
        }
        Command::Link { from, relation, to } => {
            let (a, b) = (store.resolve(&from, None)?, store.resolve(&to, None)?);
            store.relate(&a.id, relation, &b.id)?;
            println!("{} {} {}", a.title, relation, b.title);
        }
        Command::Unlink { from, relation, to } => {
            let (a, b) = (store.resolve(&from, None)?, store.resolve(&to, None)?);
            if !store.unrelate(&a.id, relation, &b.id)? {
                bail!("{} does not {} {}", a.title, relation, b.title);
            }
            println!("Removed: {} {} {}", a.title, relation, b.title);
        }
        Command::Show { reference } => {
            let obj = store.resolve(&reference, None)?;
            let related = store.related(&obj.id)?;
            if json {
                return print_json(&serde_json::json!({ "object": obj, "related": related }));
            }
            println!("{}\n{}\n", obj.kind.label(), obj.title);
            println!("  id: {}", obj.id);
            for (k, v) in &obj.properties {
                println!(
                    "  {k}: {}",
                    v.as_str()
                        .map(str::to_string)
                        .unwrap_or_else(|| v.to_string())
                );
            }
            if !obj.body.is_empty() {
                println!("\n{}", obj.body);
            }
            if !related.is_empty() {
                println!();
                let mut last = "";
                for r in &related {
                    if r.label() != last {
                        last = r.label();
                        println!("{}:", capitalize(last));
                    }
                    println!(
                        "  {} {}  {}",
                        r.object.kind.label(),
                        r.object.title,
                        short_id(&r.object)
                    );
                }
            }
        }
        Command::List { kind, limit } => {
            let objects = store.list(kind, limit)?;
            if json {
                return print_json(&objects);
            }
            for o in objects {
                let status = o
                    .prop_str("status")
                    .map(|s| format!(" [{s}]"))
                    .unwrap_or_default();
                println!(
                    "{:<8} {}{}  {}",
                    o.kind.label(),
                    o.title,
                    status,
                    short_id(&o)
                );
            }
        }
        Command::Status { task, status } => {
            let t = store.resolve(&task, Some(ObjectKind::Task))?;
            store.set_property(&t.id, "status", status.as_str().into())?;
            println!("{} → {}", t.title, status.as_str());
        }
        Command::Delete { reference, yes } => {
            let obj = store.resolve(&reference, None)?;
            if !yes {
                bail!(
                    "this removes \"{}\" from Where. Re-run with --yes to confirm.",
                    obj.title
                );
            }
            store.delete(&obj.id)?;
            println!(
                "Deleted {} \"{}\" (files on disk are untouched)",
                obj.kind, obj.title
            );
        }
        Command::Index {
            folder,
            project,
            include_hidden,
        } => {
            let mut opts = IndexOptions {
                include_hidden,
                ..Default::default()
            };
            if let Some(p) = project {
                opts.project_id = Some(store.resolve(&p, Some(ObjectKind::Project))?.id);
            }
            let reports = match folder {
                Some(f) => vec![where_indexer::index_folder(&mut store, f, &opts)?],
                None => where_indexer::reindex_all(&mut store, &opts)?,
            };
            if json {
                return print_json(&reports);
            }
            if reports.is_empty() {
                println!("No folders indexed yet. Run: where-cli index <folder>");
            }
            for r in reports {
                println!(
                    "{}: {} files — {} added, {} updated, {} unchanged, {} removed{}",
                    r.root,
                    r.scanned,
                    r.added,
                    r.updated,
                    r.unchanged,
                    r.removed,
                    if r.skipped.is_empty() {
                        String::new()
                    } else {
                        format!(", {} skipped", r.skipped.len())
                    }
                );
            }
        }
        Command::Export { format, out } => {
            let fmt: export::Format = format.parse().map_err(anyhow::Error::msg)?;
            export::export(&store, fmt, &out)?;
            println!("Exported to {}", out.display());
        }
        Command::Stats => {
            let s = store.stats()?;
            if json {
                return print_json(&s);
            }
            println!("Database: {}", db.display());
            println!(
                "Objects: {}   Relations: {}   Indexed folders: {}",
                s.objects, s.relations, s.index_roots
            );
            for (kind, n) in s.by_kind {
                println!("  {kind:<14} {n}");
            }
            println!("Cloud sync: OFF   Cloud AI: OFF   Activity tracking: OFF");
        }
        Command::Demo => demo(&store)?,
    }
    Ok(())
}

fn demo(store: &Store) -> Result<()> {
    let project = store.create(NewObject::new(ObjectKind::Project, "Cybersecurity Lab"))?;
    let children = [
        NewObject::new(ObjectKind::Task, "Build network monitor").prop("status", "todo"),
        NewObject::new(ObjectKind::Note, "Monitoring dashboard ideas"),
        NewObject::new(ObjectKind::File, "network-design.pdf").prop("extension", "pdf"),
    ];
    println!("Create project:\n  {}\n\nAdd:", project.title);
    for child in children {
        let obj = store.create(child)?;
        store.relate(&project.id, RelationKind::Contains, &obj.id)?;
        println!("  {} — {}", capitalize(obj.kind.as_str()), obj.title);
    }
    println!("\nSearch:\n  network\n\nResults:");
    let results = where_search::search(store, "network", Options::default())?;
    for (kind, hits) in results.grouped() {
        for h in hits {
            println!("  {:<8} {}", kind.label(), h.object.title);
        }
    }
    println!("\n({:.1} ms)", results.elapsed.as_secs_f64() * 1000.0);
    Ok(())
}

fn short_id(o: &Object) -> String {
    // UUIDv7 ids share a time prefix; the tail is the distinguishing part.
    format!("#{}", &o.id[o.id.len() - 8..])
}

fn capitalize(s: &str) -> String {
    let mut c = s.chars();
    c.next()
        .map(|f| f.to_uppercase().collect::<String>() + c.as_str())
        .unwrap_or_default()
}

fn print_json<T: serde::Serialize>(v: &T) -> Result<()> {
    println!("{}", serde_json::to_string_pretty(v)?);
    Ok(())
}

fn default_db_path() -> PathBuf {
    let home = std::env::var_os("HOME")
        .or_else(|| std::env::var_os("USERPROFILE"))
        .map(PathBuf::from);
    let base = if cfg!(windows) {
        std::env::var_os("APPDATA")
            .map(PathBuf::from)
            .map(|p| p.join("Where"))
    } else if cfg!(target_os = "macos") {
        home.map(|h| h.join("Library/Application Support/Where"))
    } else {
        std::env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .or_else(|| home.map(|h| h.join(".local/share")))
            .map(|p| p.join("where"))
    };
    base.unwrap_or_else(|| PathBuf::from(".")).join("where.db")
}
