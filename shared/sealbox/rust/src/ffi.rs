//! The C boundary: one call, JSON in and out.
//!
//! A failure comes back as `{"error": {"code": …, "message": …}}`, never as a
//! panic across the boundary: release builds abort on panic, so every
//! operation returns its errors instead.

use std::ffi::{CStr, CString, c_char};

use serde_json::{Value, json};

use crate::ops;

fn respond(input: &str) -> String {
    let result = serde_json::from_str::<Value>(input)
        .map_err(|e| ops::OpError {
            code: "bad_input",
            message: format!("not JSON: {e}"),
        })
        .and_then(|value| ops::call(&value));
    match result {
        Ok(value) => value.to_string(),
        Err(e) => json!({ "error": { "code": e.code, "message": e.message } }).to_string(),
    }
}

/// # Safety
/// `input` is a valid NUL-terminated UTF-8 string. The result goes back through
/// [`sealbox_free`], once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn sealbox_call(input: *const c_char) -> *mut c_char {
    let input = unsafe { CStr::from_ptr(input) };
    let output = match input.to_str() {
        Ok(text) => respond(text),
        Err(_) => {
            json!({ "error": { "code": "bad_input", "message": "input isn't UTF-8" } }).to_string()
        }
    };
    // JSON escapes control characters, so the output holds no interior NUL
    CString::new(output).expect("JSON has no NUL").into_raw()
}

/// # Safety
/// `output` came from [`sealbox_call`] and is freed once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn sealbox_free(output: *mut c_char) {
    if !output.is_null() {
        drop(unsafe { CString::from_raw(output) });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn errors_come_back_as_json() {
        let out: Value = serde_json::from_str(&respond("{")).unwrap();
        assert_eq!(out["error"]["code"], "bad_input");
        let out: Value = serde_json::from_str(&respond(r#"{"op":"nope"}"#)).unwrap();
        assert_eq!(out["error"]["code"], "unknown_op");
    }

    #[test]
    fn the_c_boundary_round_trips() {
        let input = CString::new(r#"{"op":"noteKey"}"#).unwrap();
        let output = unsafe { sealbox_call(input.as_ptr()) };
        let text = unsafe { CStr::from_ptr(output) }
            .to_str()
            .unwrap()
            .to_owned();
        unsafe { sealbox_free(output) };
        let value: Value = serde_json::from_str(&text).unwrap();
        assert!(value["key"].is_string());
    }
}
