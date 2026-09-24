//! Versioned schema migrations. Append new migrations; never edit old ones.

pub const MIGRATIONS: &[&str] = &[
    // v1 — objects, relations, full-text index, indexed folder roots.
    r#"
    CREATE TABLE objects (
        id          TEXT PRIMARY KEY,
        kind        TEXT NOT NULL,
        title       TEXT NOT NULL,
        body        TEXT NOT NULL DEFAULT '',
        properties  TEXT NOT NULL DEFAULT '{}',
        search_extra TEXT NOT NULL DEFAULT '',
        source_key  TEXT UNIQUE,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
    );
    CREATE INDEX idx_objects_kind ON objects(kind);
    CREATE INDEX idx_objects_updated ON objects(updated_at);

    CREATE TABLE relations (
        from_id    TEXT NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
        kind       TEXT NOT NULL,
        to_id      TEXT NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL,
        PRIMARY KEY (from_id, kind, to_id)
    );
    CREATE INDEX idx_relations_to ON relations(to_id);

    CREATE VIRTUAL TABLE objects_fts USING fts5(
        title, body, search_extra,
        content='objects', content_rowid='rowid',
        tokenize='unicode61 remove_diacritics 2'
    );

    CREATE TRIGGER objects_ai AFTER INSERT ON objects BEGIN
        INSERT INTO objects_fts(rowid, title, body, search_extra)
        VALUES (new.rowid, new.title, new.body, new.search_extra);
    END;
    CREATE TRIGGER objects_ad AFTER DELETE ON objects BEGIN
        INSERT INTO objects_fts(objects_fts, rowid, title, body, search_extra)
        VALUES ('delete', old.rowid, old.title, old.body, old.search_extra);
    END;
    CREATE TRIGGER objects_au AFTER UPDATE ON objects BEGIN
        INSERT INTO objects_fts(objects_fts, rowid, title, body, search_extra)
        VALUES ('delete', old.rowid, old.title, old.body, old.search_extra);
        INSERT INTO objects_fts(rowid, title, body, search_extra)
        VALUES (new.rowid, new.title, new.body, new.search_extra);
    END;

    CREATE TABLE index_roots (
        path       TEXT PRIMARY KEY,
        folder_id  TEXT NOT NULL REFERENCES objects(id) ON DELETE CASCADE,
        last_indexed_at TEXT
    );
    "#,
];
