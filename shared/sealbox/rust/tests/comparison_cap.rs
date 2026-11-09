//! On its own, as a binary of its own: running comparisons are process-wide,
//! and a test beside it starting its own would race this one.

use sealbox::ops::call;
use serde_json::json;

/// A comparison holds key material, so an uncapped map would keep every one a
/// caller forgot to end for the life of the process.
#[test]
fn at_most_sixteen_comparisons_run_at_once() {
    let started: Vec<_> = (0..16)
        .map(|_| call(&json!({ "op": "comparisonStart" })).unwrap()["comparison"].clone())
        .collect();
    let refused = call(&json!({ "op": "comparisonStart" })).unwrap_err();
    assert_eq!(refused.code, "too_many_comparisons");

    // ending one makes room again
    call(&json!({ "op": "comparisonEnd", "comparison": started[0] })).unwrap();
    assert!(call(&json!({ "op": "comparisonStart" })).is_ok());
}
