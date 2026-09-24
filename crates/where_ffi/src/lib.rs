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

#[cfg(test)]
mod tests {
    use super::*;

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
