//! Universal search (spec §9, §24).
//!
//! Search is keyword-based and fully local. A query is plain words plus
//! optional filters such as `kind:task` (or `is:task`). Results include
//! direct matches and — because relationships are the point of Where — the
//! projects and other containers that hold those matches, so searching
//! "network" also surfaces the "Cybersecurity Lab" project.
//!
//! No AI is required. Natural-language and semantic search (spec §10, §25)
//! are meant to layer on top of this, not replace it.

use std::collections::HashMap;
use std::time::{Duration, Instant};

use serde::Serialize;
use where_core::{Object, ObjectKind};
use where_storage::{Result, Store};

/// Container results are ranked below the direct match that surfaced them.
const CONTAINER_SCORE_FACTOR: f64 = 0.8;

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Query {
    pub terms: Vec<String>,
    pub kinds: Vec<ObjectKind>,
}

impl Query {
    /// Parse user input. Unknown `kind:` values are kept as plain terms.
    pub fn parse(input: &str) -> Self {
        let mut q = Query::default();
        for raw in input.split_whitespace() {
            if let Some((key, value)) = raw.split_once(':') {
                if matches!(key.to_ascii_lowercase().as_str(), "kind" | "is" | "type") {
                    if let Ok(kind) = value.parse::<ObjectKind>() {
                        if !q.kinds.contains(&kind) {
                            q.kinds.push(kind);
                        }
                        continue;
                    }
                }
            }
            q.terms.extend(tokenize(raw));
        }
        q
    }

    pub fn is_empty(&self) -> bool {
        self.terms.is_empty() && self.kinds.is_empty()
    }

    /// Build a safe FTS5 expression: every term quoted and prefix-matched,
    /// combined with AND. User input never reaches FTS5 syntax unescaped.
    pub fn to_fts(&self) -> Option<String> {
        if self.terms.is_empty() {
            return None;
        }
        Some(
            self.terms
                .iter()
                .map(|t| format!("\"{}\"*", t.replace('"', "")))
                .collect::<Vec<_>>()
                .join(" AND "),
        )
    }
}

/// Split on anything that is not a letter or digit, lower-cased.
/// Mirrors FTS5's `unicode61` tokenizer closely enough for query building.
fn tokenize(s: &str) -> Vec<String> {
    s.split(|c: char| !c.is_alphanumeric())
        .filter(|t| !t.is_empty())
        .map(str::to_lowercase)
        .collect()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum MatchReason {
    /// The object's own text matched.
    Direct,
    /// The object contains something that matched.
    Contains,
}

#[derive(Debug, Clone, Serialize)]
pub struct Hit {
    pub object: Object,
    pub score: f64,
    pub reason: MatchReason,
    /// Titles of direct matches that pulled this container into the results.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub via: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SearchResults {
    pub query: String,
    pub hits: Vec<Hit>,
    #[serde(serialize_with = "ser_duration_ms")]
    pub elapsed: Duration,
}

fn ser_duration_ms<S: serde::Serializer>(
    d: &Duration,
    s: S,
) -> std::result::Result<S::Ok, S::Error> {
    s.serialize_f64(d.as_secs_f64() * 1000.0)
}

impl SearchResults {
    /// Hits grouped by kind in display order (PROJECT, TASK, NOTE, FILE, …).
    pub fn grouped(&self) -> Vec<(ObjectKind, Vec<&Hit>)> {
        let mut groups: Vec<(ObjectKind, Vec<&Hit>)> = Vec::new();
        for hit in &self.hits {
            match groups.iter_mut().find(|(k, _)| *k == hit.object.kind) {
                Some((_, v)) => v.push(hit),
                None => groups.push((hit.object.kind, vec![hit])),
            }
        }
        groups.sort_by_key(|(k, _)| k.display_rank());
        groups
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Options {
    pub limit: usize,
    /// Surface containers (e.g. projects) of matching objects.
    pub include_containers: bool,
}

impl Default for Options {
    fn default() -> Self {
        Self {
            limit: 50,
            include_containers: true,
        }
    }
}

pub fn search(store: &Store, input: &str, opts: Options) -> Result<SearchResults> {
    let started = Instant::now();
    let query = Query::parse(input);
    let mut hits: Vec<Hit> = Vec::new();

    match query.to_fts() {
        // Filter-only query, e.g. "kind:task": list most recent of those kinds.
        None if !query.kinds.is_empty() => {
            for kind in &query.kinds {
                for object in store.list(Some(*kind), opts.limit)? {
                    hits.push(Hit {
                        object,
                        score: 0.0,
                        reason: MatchReason::Direct,
                        via: vec![],
                    });
                }
            }
        }
        None => {}
        Some(_) => {
            // Containers are found from all matches, then kind filters applied.
            let direct = contextual_matches(store, &query, opts.limit)?;
            let mut index: HashMap<String, usize> = HashMap::new();
            for (object, score) in &direct {
                index.insert(object.id.clone(), hits.len());
                hits.push(Hit {
                    object: object.clone(),
                    score: *score,
                    reason: MatchReason::Direct,
                    via: vec![],
                });
            }
            if opts.include_containers {
                for (object, score) in &direct {
                    for container in store.containers_of(&object.id)? {
                        let s = score * CONTAINER_SCORE_FACTOR;
                        match index.get(&container.id) {
                            Some(&i) => {
                                let hit = &mut hits[i];
                                if hit.reason == MatchReason::Contains {
                                    hit.score = hit.score.max(s);
                                    hit.via.push(object.title.clone());
                                }
                            }
                            None => {
                                index.insert(container.id.clone(), hits.len());
                                hits.push(Hit {
                                    object: container,
                                    score: s,
                                    reason: MatchReason::Contains,
                                    via: vec![object.title.clone()],
                                });
                            }
                        }
                    }
                }
            }
            if !query.kinds.is_empty() {
                hits.retain(|h| query.kinds.contains(&h.object.kind));
            }
        }
    }

    hits.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    hits.truncate(opts.limit);
    Ok(SearchResults {
        query: input.to_string(),
        hits,
        elapsed: started.elapsed(),
    })
}

/// Objects where every term matches either the object itself or one of its
/// containers. "website authentication" therefore finds the task
/// "Fix Firebase authentication" inside the "Website" project (spec §9).
fn contextual_matches(store: &Store, query: &Query, limit: usize) -> Result<Vec<(Object, f64)>> {
    // term index -> (object id -> score)
    let mut per_term: Vec<HashMap<String, f64>> = Vec::with_capacity(query.terms.len());
    let mut objects: HashMap<String, Object> = HashMap::new();
    for term in &query.terms {
        let single = Query {
            terms: vec![term.clone()],
            kinds: vec![],
        };
        let fts = single.to_fts().expect("non-empty term");
        let mut scores = HashMap::new();
        for (obj, score) in store.search_fts(&fts, &[], PER_TERM_CANDIDATES)? {
            scores.insert(obj.id.clone(), score);
            objects.entry(obj.id.clone()).or_insert(obj);
        }
        per_term.push(scores);
    }

    let mut out = Vec::new();
    'candidates: for (id, obj) in objects {
        let mut containers: Option<Vec<Object>> = None;
        let mut total = 0.0;
        for scores in &per_term {
            if let Some(s) = scores.get(&id) {
                total += s;
                continue;
            }
            let cs = match &containers {
                Some(c) => c,
                None => containers.insert(store.containers_of(&id)?),
            };
            match cs
                .iter()
                .filter_map(|c| scores.get(&c.id))
                .cloned()
                .reduce(f64::max)
            {
                Some(s) => total += s * CONTEXT_TERM_FACTOR,
                None => continue 'candidates,
            }
        }
        out.push((obj, total));
    }
    out.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    out.truncate(limit);
    Ok(out)
}

/// How many matches to consider per term before intersecting.
const PER_TERM_CANDIDATES: usize = 500;
/// A term satisfied by a container counts for less than a direct match.
const CONTEXT_TERM_FACTOR: f64 = 0.5;

#[cfg(test)]
mod tests {
    use super::*;
    use where_core::{NewObject, RelationKind};

    /// The example from spec §39.
    fn cybersecurity_lab() -> Store {
        let s = Store::open_in_memory().unwrap();
        let p = s
            .create(NewObject::new(ObjectKind::Project, "Cybersecurity Lab"))
            .unwrap();
        let t = s
            .create(NewObject::new(ObjectKind::Task, "Build network monitor"))
            .unwrap();
        let n = s
            .create(NewObject::new(
                ObjectKind::Note,
                "Monitoring dashboard ideas",
            ))
            .unwrap();
        let f = s
            .create(NewObject::new(ObjectKind::File, "network-design.pdf").prop("extension", "pdf"))
            .unwrap();
        for child in [&t, &n, &f] {
            s.relate(&p.id, RelationKind::Contains, &child.id).unwrap();
        }
        s.create(NewObject::new(ObjectKind::Note, "Groceries"))
            .unwrap();
        s
    }

    fn titles(r: &SearchResults) -> Vec<&str> {
        r.hits.iter().map(|h| h.object.title.as_str()).collect()
    }

    #[test]
    fn parse_filters_and_terms() {
        let q = Query::parse("kind:task Website auth.dart is:note kind:bogus");
        assert_eq!(q.kinds, vec![ObjectKind::Task, ObjectKind::Note]);
        assert_eq!(q.terms, vec!["website", "auth", "dart", "kind", "bogus"]);
    }

    #[test]
    fn fts_escapes_user_input() {
        let q = Query::parse("\"a\" OR NEAR(b) *");
        let fts = q.to_fts().unwrap();
        assert_eq!(fts, "\"a\"* AND \"or\"* AND \"near\"* AND \"b\"*");
    }

    #[test]
    fn spec_example_network_finds_project_via_children() {
        let r = search(&cybersecurity_lab(), "network", Options::default()).unwrap();
        let t = titles(&r);
        assert!(t.contains(&"Build network monitor"));
        assert!(t.contains(&"network-design.pdf"));
        assert!(
            t.contains(&"Cybersecurity Lab"),
            "project should surface via its children: {t:?}"
        );
        assert!(!t.contains(&"Groceries"));
        let project = r
            .hits
            .iter()
            .find(|h| h.object.kind == ObjectKind::Project)
            .unwrap();
        assert_eq!(project.reason, MatchReason::Contains);
        assert_eq!(project.via.len(), 2);
        assert_eq!(r.grouped()[0].0, ObjectKind::Project);
    }

    #[test]
    fn spec_example_terms_can_match_through_project() {
        let s = Store::open_in_memory().unwrap();
        let p = s
            .create(NewObject::new(ObjectKind::Project, "Website"))
            .unwrap();
        let t = s
            .create(NewObject::new(
                ObjectKind::Task,
                "Fix Firebase authentication",
            ))
            .unwrap();
        s.relate(&p.id, RelationKind::Contains, &t.id).unwrap();
        s.create(NewObject::new(
            ObjectKind::Task,
            "Authentication for the mobile app",
        ))
        .unwrap();
        let r = search(&s, "website authentication", Options::default()).unwrap();
        let t = titles(&r);
        assert!(t.contains(&"Fix Firebase authentication"), "{t:?}");
        assert!(t.contains(&"Website"));
        assert!(!t.contains(&"Authentication for the mobile app"));
    }

    #[test]
    fn prefix_matching() {
        let r = search(&cybersecurity_lab(), "monitor", Options::default()).unwrap();
        // "monitor" should match both "monitor" and "Monitoring".
        assert!(titles(&r).contains(&"Monitoring dashboard ideas"));
    }

    #[test]
    fn kind_filter() {
        let r = search(
            &cybersecurity_lab(),
            "network kind:file",
            Options::default(),
        )
        .unwrap();
        assert_eq!(titles(&r), vec!["network-design.pdf"]);
        let r = search(&cybersecurity_lab(), "kind:note", Options::default()).unwrap();
        assert_eq!(r.hits.len(), 2);
    }

    #[test]
    fn empty_and_punctuation_only_queries() {
        assert!(search(&cybersecurity_lab(), "", Options::default())
            .unwrap()
            .hits
            .is_empty());
        assert!(search(&cybersecurity_lab(), "  ***  ", Options::default())
            .unwrap()
            .hits
            .is_empty());
    }
}
