//! C ABI for the Flutter client.
//!
//! Deliberately small and JSON-based: every call takes UTF-8 C strings and
//! returns a heap-allocated JSON string of the form
//! `{"ok": <value>}` or `{"error": "<message>"}`, which the caller must free
//! with [`where_string_free`]. This keeps the Dart side trivial and lets the
//! API evolve without regenerating bindings. It can be replaced with
//! flutter_rust_bridge later if the surface grows (see docs/adr/0003).
//!
//! # Safety
//! All pointer arguments must be valid, NUL-terminated UTF-8 strings (or a
//! handle returned by [`where_open`]). Handles are not thread-safe across
//! concurrent calls from Dart isolates; a mutex guards each handle.

// Safety requirements are documented once, at module level, for every function.
#![allow(clippy::missing_safety_doc)]

use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

use serde::Serialize;
use serde_json::{json, Value};
use where_core::{NewObject, ObjectKind, RelationKind};
use where_storage::Store;

pub struct Handle(Mutex<Store>);

fn respond<T: Serialize>(result: Result<T, String>) -> *mut c_char {
    let body = match result {
        Ok(v) => json!({ "ok": v }),
        Err(e) => json!({ "error": e }),
    };
    CString::new(body.to_string())
        .unwrap_or_default()
        .into_raw()
}

unsafe fn arg<'a>(p: *const c_char) -> Result<&'a str, String> {
    if p.is_null() {
        return Err("null argument".into());
    }
    CStr::from_ptr(p).to_str().map_err(|e| e.to_string())
}

unsafe fn with_store<T: Serialize>(
    h: *mut Handle,
    f: impl FnOnce(&mut Store) -> Result<T, String>,
) -> *mut c_char {
    if h.is_null() {
        return respond::<()>(Err("null handle".into()));
    }
    let handle = &*h;
    let mut guard = match handle.0.lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    };
    respond(f(&mut guard))
}

fn err<E: std::fmt::Display>(e: E) -> String {
    e.to_string()
}

/// Open (or create) a database. Returns null on failure.
#[no_mangle]
pub unsafe extern "C" fn where_open(path: *const c_char) -> *mut Handle {
    let Ok(path) = arg(path) else {
        return std::ptr::null_mut();
    };
    match Store::open(path) {
        Ok(store) => Box::into_raw(Box::new(Handle(Mutex::new(store)))),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn where_close(h: *mut Handle) {
    if !h.is_null() {
        drop(Box::from_raw(h));
    }
}

#[no_mangle]
pub unsafe extern "C" fn where_string_free(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

/// `query` → `{"ok": SearchResults}`
#[no_mangle]
pub unsafe extern "C" fn where_search(
    h: *mut Handle,
    query: *const c_char,
    limit: u32,
) -> *mut c_char {
    let q = match arg(query) {
        Ok(q) => q.to_string(),
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| {
        let opts = where_search::Options {
            limit: limit.max(1) as usize,
            ..Default::default()
        };
        where_search::search(s, &q, opts).map_err(err)
    })
}

/// `request` = `{"kind": "task", "title": "...", "body": "...", "project_id": "...", "properties": {...}}`
#[no_mangle]
pub unsafe extern "C" fn where_create(h: *mut Handle, request: *const c_char) -> *mut c_char {
    let req: Value = match arg(request).and_then(|r| serde_json::from_str(r).map_err(err)) {
        Ok(v) => v,
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| {
        let kind: ObjectKind = req["kind"]
            .as_str()
            .unwrap_or_default()
            .parse()
            .map_err(err)?;
        let mut new = NewObject::new(kind, req["title"].as_str().unwrap_or_default())
            .body(req["body"].as_str().unwrap_or_default());
        if let Some(props) = req["properties"].as_object() {
            new.properties = props.clone();
        }
        let obj = s.create(new).map_err(err)?;
        if let Some(pid) = req["project_id"].as_str() {
            s.relate(pid, RelationKind::Contains, &obj.id)
                .map_err(err)?;
        }
        Ok(obj)
    })
}

/// `id` → `{"ok": {"object": Object, "related": [Related]}}`
#[no_mangle]
pub unsafe extern "C" fn where_get(h: *mut Handle, id: *const c_char) -> *mut c_char {
    let id = match arg(id) {
        Ok(v) => v.to_string(),
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| {
        let object = s.get(&id).map_err(err)?;
        let related = s.related(&id).map_err(err)?;
        Ok(json!({ "object": object, "related": related }))
    })
}

/// Recent objects, optionally filtered by kind (empty string = all).
#[no_mangle]
pub unsafe extern "C" fn where_recent(
    h: *mut Handle,
    kind: *const c_char,
    limit: u32,
) -> *mut c_char {
    let kind = match arg(kind) {
        Ok("") => None,
        Ok(k) => match k.parse::<ObjectKind>() {
            Ok(k) => Some(k),
            Err(e) => return respond::<()>(Err(e.to_string())),
        },
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| s.list(kind, limit.max(1) as usize).map_err(err))
}

/// Index a folder the user picked → `{"ok": IndexReport}`
#[no_mangle]
pub unsafe extern "C" fn where_index_folder(h: *mut Handle, path: *const c_char) -> *mut c_char {
    let path = match arg(path) {
        Ok(v) => v.to_string(),
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| {
        where_indexer::index_folder(s, &path, &Default::default()).map_err(err)
    })
}

#[no_mangle]
pub unsafe extern "C" fn where_stats(h: *mut Handle) -> *mut c_char {
    with_store(h, |s| s.stats().map_err(err))
}

unsafe fn json_arg(p: *const c_char) -> Result<Value, String> {
    arg(p).and_then(|s| serde_json::from_str(s).map_err(err))
}

/// `{"id": "...", "title"?: "...", "body"?: "...", "properties"?: {...}}`
/// Properties are merged; a `null` value removes that property.
#[no_mangle]
pub unsafe extern "C" fn where_update(h: *mut Handle, request: *const c_char) -> *mut c_char {
    let req = match json_arg(request) {
        Ok(v) => v,
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| {
        let id = req["id"].as_str().ok_or("id is required")?;
        let mut obj = s.get(id).map_err(err)?;
        if let Some(title) = req["title"].as_str() {
            if title.trim().is_empty() {
                return Err("title must not be empty".to_string());
            }
            obj.title = title.trim().to_string();
        }
        if let Some(body) = req["body"].as_str() {
            obj.body = body.to_string();
        }
        if let Some(props) = req["properties"].as_object() {
            for (k, v) in props {
                if v.is_null() {
                    obj.properties.remove(k);
                } else {
                    obj.properties.insert(k.clone(), v.clone());
                }
            }
        }
        s.save(&mut obj).map_err(err)?;
        Ok(obj)
    })
}

/// Remove an object from Where. Never touches files on disk.
#[no_mangle]
pub unsafe extern "C" fn where_delete(h: *mut Handle, id: *const c_char) -> *mut c_char {
    let id = match arg(id) {
        Ok(v) => v.to_string(),
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| s.delete(&id).map_err(err))
}

/// `{"from": id, "kind": "contains", "to": id, "remove"?: bool}`
#[no_mangle]
pub unsafe extern "C" fn where_relate(h: *mut Handle, request: *const c_char) -> *mut c_char {
    let req = match json_arg(request) {
        Ok(v) => v,
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| {
        let from = req["from"].as_str().ok_or("from is required")?;
        let to = req["to"].as_str().ok_or("to is required")?;
        let kind: RelationKind = req["kind"]
            .as_str()
            .unwrap_or("contains")
            .parse()
            .map_err(err)?;
        if req["remove"].as_bool().unwrap_or(false) {
            s.unrelate(from, kind, to).map_err(err)?;
        } else {
            s.relate(from, kind, to).map_err(err)?;
        }
        Ok(())
    })
}

/// Folders the user has indexed → `[{"path": ..., "folder_id": ...}]`
#[no_mangle]
pub unsafe extern "C" fn where_index_roots(h: *mut Handle) -> *mut c_char {
    with_store(h, |s| {
        let roots = s.index_roots().map_err(err)?;
        Ok(roots
            .into_iter()
            .map(|(path, folder_id)| json!({ "path": path, "folder_id": folder_id }))
            .collect::<Vec<_>>())
    })
}

/// Refresh every indexed folder → `[IndexReport]`
#[no_mangle]
pub unsafe extern "C" fn where_reindex_all(h: *mut Handle) -> *mut c_char {
    with_store(h, |s| {
        where_indexer::reindex_all(s, &Default::default()).map_err(err)
    })
}

/// `{"format": "json"|"md"|"csv"|"sqlite", "path": "..."}`
#[no_mangle]
pub unsafe extern "C" fn where_export(h: *mut Handle, request: *const c_char) -> *mut c_char {
    let req = match json_arg(request) {
        Ok(v) => v,
        Err(e) => return respond::<()>(Err(e)),
    };
    with_store(h, |s| {
        let format: where_storage::export::Format =
            req["format"].as_str().unwrap_or("json").parse()?;
        let path = req["path"].as_str().ok_or("path is required")?;
        where_storage::export::export(s, format, std::path::Path::new(path)).map_err(err)?;
        Ok(path.to_string())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn update_delete_relate_export() {
        unsafe {
            let h = where_open(c":memory:".as_ptr());
            let cstr = |v: Value| CString::new(v.to_string()).unwrap();
            let p = call(where_create(
                h,
                cstr(json!({"kind":"project","title":"Lab"})).as_ptr(),
            ));
            let t = call(where_create(
                h,
                cstr(json!({"kind":"task","title":"Monitor","properties":{"status":"todo"}}))
                    .as_ptr(),
            ));
            let (pid, tid) = (
                p["ok"]["id"].as_str().unwrap(),
                t["ok"]["id"].as_str().unwrap(),
            );

            let u = call(where_update(
                h,
                cstr(json!({"id":tid,"title":"Build monitor","properties":{"status":"done"}}))
                    .as_ptr(),
            ));
            assert_eq!(u["ok"]["title"], "Build monitor");
            assert_eq!(u["ok"]["properties"]["status"], "done");
            let bad = call(where_update(
                h,
                cstr(json!({"id":tid,"title":"  "})).as_ptr(),
            ));
            assert!(bad["error"].is_string());

            call(where_relate(
                h,
                cstr(json!({"from":pid,"kind":"contains","to":tid})).as_ptr(),
            ));
            let id_c = CString::new(pid).unwrap();
            assert_eq!(
                call(where_get(h, id_c.as_ptr()))["ok"]["related"]
                    .as_array()
                    .unwrap()
                    .len(),
                1
            );
            call(where_relate(
                h,
                cstr(json!({"from":pid,"to":tid,"remove":true})).as_ptr(),
            ));
            assert!(call(where_get(h, id_c.as_ptr()))["ok"]["related"]
                .as_array()
                .unwrap()
                .is_empty());

            let dir = std::env::temp_dir().join(format!("where-ffi-{}.json", std::process::id()));
            let e = call(where_export(
                h,
                cstr(json!({"format":"json","path":dir.to_string_lossy()})).as_ptr(),
            ));
            assert!(e["ok"].is_string(), "{e}");
            assert!(std::fs::read_to_string(&dir)
                .unwrap()
                .contains("Build monitor"));
            let _ = std::fs::remove_file(&dir);

            let tid_c = CString::new(tid).unwrap();
            assert!(call(where_delete(h, tid_c.as_ptr()))["error"].is_null());
            assert!(call(where_get(h, tid_c.as_ptr()))["error"].is_string());
            assert!(call(where_index_roots(h))["ok"]
                .as_array()
                .unwrap()
                .is_empty());
            where_close(h);
        }
    }

    unsafe fn call(p: *mut c_char) -> Value {
        let v = serde_json::from_str(CStr::from_ptr(p).to_str().unwrap()).unwrap();
        where_string_free(p);
        v
    }

    #[test]
    fn round_trip_through_c_abi() {
        unsafe {
            let h = where_open(c":memory:".as_ptr());
            assert!(!h.is_null());
            let p = call(where_create(
                h,
                c"{\"kind\":\"project\",\"title\":\"Website\"}".as_ptr(),
            ));
            let pid = p["ok"]["id"].as_str().unwrap().to_string();
            let req = CString::new(
                json!({"kind":"task","title":"Fix authentication","project_id":pid}).to_string(),
            )
            .unwrap();
            call(where_create(h, req.as_ptr()));

            let r = call(where_search(h, c"auth".as_ptr(), 10));
            let titles: Vec<_> = r["ok"]["hits"]
                .as_array()
                .unwrap()
                .iter()
                .map(|h| h["object"]["title"].as_str().unwrap())
                .collect();
            assert_eq!(titles, vec!["Fix authentication", "Website"]);

            let bad = call(where_create(
                h,
                c"{\"kind\":\"spaceship\",\"title\":\"x\"}".as_ptr(),
            ));
            assert!(bad["error"]
                .as_str()
                .unwrap()
                .contains("unknown object kind"));
            assert!(
                call(where_recent(h, c"task".as_ptr(), 5))["ok"]
                    .as_array()
                    .unwrap()
                    .len()
                    == 1
            );
            where_close(h);
        }
    }
}
