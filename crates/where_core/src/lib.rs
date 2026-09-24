//! Core object and relationship model for Where (spec §7–§8).
//!
//! Everything Where knows about is an [`Object`]. Objects are connected by
//! directed [`Relation`]s. Only the canonical direction is stored
//! (e.g. `Project --contains--> Task`); the inverse ("part of") is derived.

use std::fmt;
use std::str::FromStr;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

pub type Timestamp = DateTime<Utc>;
pub type Properties = Map<String, Value>;

#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("unknown object kind: {0}")]
    UnknownKind(String),
    #[error("unknown relation kind: {0}")]
    UnknownRelation(String),
}

macro_rules! string_enum {
    ($(#[$meta:meta])* $name:ident, $err:ident { $($variant:ident => $s:literal),+ $(,)? }) => {
        $(#[$meta])*
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
        #[serde(rename_all = "snake_case")]
        pub enum $name { $($variant),+ }

        impl $name {
            pub const ALL: &'static [$name] = &[$($name::$variant),+];
            pub fn as_str(self) -> &'static str {
                match self { $($name::$variant => $s),+ }
            }
        }

        impl fmt::Display for $name {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result { f.write_str(self.as_str()) }
        }

        impl FromStr for $name {
            type Err = CoreError;
            fn from_str(s: &str) -> Result<Self, Self::Err> {
                match s.trim().to_ascii_lowercase().as_str() {
                    $($s => Ok($name::$variant),)+
                    other => Err(CoreError::$err(other.to_string())),
                }
            }
        }
    };
}

string_enum!(
    /// The kinds of object Where understands (spec §7).
    ObjectKind, UnknownKind {
        Project => "project",
        Task => "task",
        Note => "note",
        File => "file",
        Folder => "folder",
        Person => "person",
        Application => "application",
        Website => "website",
        Conversation => "conversation",
        CalendarEvent => "calendar_event",
        Device => "device",
        Bookmark => "bookmark",
        Image => "image",
        Video => "video",
        Repository => "repository",
        Organization => "organization",
    }
);

impl ObjectKind {
    /// Display order used when grouping search results (spec §9).
    pub fn display_rank(self) -> usize {
        Self::ALL
            .iter()
            .position(|k| *k == self)
            .unwrap_or(usize::MAX)
    }

    /// Upper-case heading used when displaying grouped results.
    pub fn label(self) -> &'static str {
        LABELS[self.display_rank()]
    }
}

const LABELS: &[&str] = &[
    "PROJECT",
    "TASK",
    "NOTE",
    "FILE",
    "FOLDER",
    "PERSON",
    "APP",
    "WEBSITE",
    "CONVERSATION",
    "EVENT",
    "DEVICE",
    "BOOKMARK",
    "IMAGE",
    "VIDEO",
    "REPOSITORY",
    "ORGANIZATION",
];

string_enum!(
    /// Directed relationship kinds (spec §8).
    RelationKind, UnknownRelation {
        Contains => "contains",
        Involves => "involves",
        References => "references",
    }
);

impl RelationKind {
    /// How the relation reads from the target's side.
    pub fn inverse_label(self) -> &'static str {
        match self {
            RelationKind::Contains => "part of",
            RelationKind::Involves => "involved in",
            RelationKind::References => "referenced by",
        }
    }
}

/// Task status (spec §15).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    Todo,
    InProgress,
    Done,
}

impl TaskStatus {
    pub fn as_str(self) -> &'static str {
        match self {
            TaskStatus::Todo => "todo",
            TaskStatus::InProgress => "in_progress",
            TaskStatus::Done => "done",
        }
    }
}

impl FromStr for TaskStatus {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s
            .trim()
            .to_ascii_lowercase()
            .replace([' ', '-'], "_")
            .as_str()
        {
            "todo" | "to_do" => Ok(TaskStatus::Todo),
            "in_progress" | "doing" => Ok(TaskStatus::InProgress),
            "done" | "complete" | "completed" => Ok(TaskStatus::Done),
            other => Err(format!("unknown task status: {other}")),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Object {
    pub id: String,
    pub kind: ObjectKind,
    pub title: String,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub body: String,
    #[serde(default, skip_serializing_if = "Map::is_empty")]
    pub properties: Properties,
    /// Stable identity for objects that mirror something outside Where,
    /// e.g. `file:/home/me/report.pdf`. Used to de-duplicate on re-index.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_key: Option<String>,
    pub created_at: Timestamp,
    pub updated_at: Timestamp,
}

impl Object {
    pub fn prop_str(&self, key: &str) -> Option<&str> {
        self.properties.get(key).and_then(Value::as_str)
    }
}

/// Input for creating an object. Ids and timestamps are assigned by storage.
#[derive(Debug, Clone, Default)]
pub struct NewObject {
    pub kind: Option<ObjectKind>,
    pub title: String,
    pub body: String,
    pub properties: Properties,
    pub source_key: Option<String>,
}

impl NewObject {
    pub fn new(kind: ObjectKind, title: impl Into<String>) -> Self {
        Self {
            kind: Some(kind),
            title: title.into(),
            ..Default::default()
        }
    }
    pub fn body(mut self, body: impl Into<String>) -> Self {
        self.body = body.into();
        self
    }
    pub fn prop(mut self, key: &str, value: impl Into<Value>) -> Self {
        self.properties.insert(key.to_string(), value.into());
        self
    }
    pub fn source_key(mut self, key: impl Into<String>) -> Self {
        self.source_key = Some(key.into());
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Relation {
    pub from_id: String,
    pub kind: RelationKind,
    pub to_id: String,
    pub created_at: Timestamp,
}

/// Which side of a relation an object is on, relative to the object being viewed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Direction {
    Outgoing,
    Incoming,
}

/// A relation seen from one object's point of view.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Related {
    pub kind: RelationKind,
    pub direction: Direction,
    pub object: Object,
}

impl Related {
    pub fn label(&self) -> &'static str {
        match self.direction {
            Direction::Outgoing => self.kind.as_str(),
            Direction::Incoming => self.kind.inverse_label(),
        }
    }
}

pub fn new_id() -> String {
    uuid::Uuid::now_v7().to_string()
}

pub fn now() -> Timestamp {
    Utc::now()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kinds_round_trip() {
        for k in ObjectKind::ALL {
            assert_eq!(k.as_str().parse::<ObjectKind>().unwrap(), *k);
            assert!(!k.label().is_empty());
        }
        assert_eq!(ObjectKind::ALL.len(), LABELS.len());
        assert_eq!(ObjectKind::Task.label(), "TASK");
        assert_eq!(ObjectKind::CalendarEvent.label(), "EVENT");
    }

    #[test]
    fn relation_labels() {
        assert_eq!(
            "CONTAINS".parse::<RelationKind>().unwrap(),
            RelationKind::Contains
        );
        assert_eq!(RelationKind::Contains.inverse_label(), "part of");
        assert!("owns".parse::<RelationKind>().is_err());
    }

    #[test]
    fn task_status_parsing() {
        assert_eq!(
            "In Progress".parse::<TaskStatus>().unwrap(),
            TaskStatus::InProgress
        );
        assert_eq!("done".parse::<TaskStatus>().unwrap(), TaskStatus::Done);
    }
}
