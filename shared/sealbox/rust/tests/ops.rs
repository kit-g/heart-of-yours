//! The operations as the Dart side calls them: JSON in, JSON out, state kept
//! by the caller between calls.

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use sealbox::ops::call;
use serde_json::{Value, json};

fn storage_key() -> String {
    STANDARD.encode([9u8; 32])
}

fn op(name: &str, mut args: Value) -> Value {
    args["op"] = json!(name);
    call(&args).unwrap_or_else(|e| panic!("{name}: {} {}", e.code, e.message))
}

fn fails(name: &str, mut args: Value) -> &'static str {
    args["op"] = json!(name);
    call(&args).expect_err(name).code
}

/// One device: its account state, and its public keys.
struct Device {
    account: String,
    identity: String,
    signing: String,
    one_time_keys: Vec<String>,
}

fn device() -> Device {
    let made = op(
        "accountNew",
        json!({ "storageKey": storage_key(), "oneTimeKeys": 5 }),
    );
    Device {
        account: made["account"].as_str().unwrap().into(),
        identity: made["identityKey"].as_str().unwrap().into(),
        signing: made["signingKey"].as_str().unwrap().into(),
        one_time_keys: made["oneTimeKeys"]
            .as_array()
            .unwrap()
            .iter()
            .map(|k| k["key"].as_str().unwrap().into())
            .collect(),
    }
}

#[test]
fn two_devices_hold_a_session_both_ways() {
    let (alice, mut bob) = (device(), device());
    let out = op(
        "sessionOutbound",
        json!({ "storageKey": storage_key(), "account": alice.account, "identityKey": bob.identity, "oneTimeKey": bob.one_time_keys[0] }),
    );
    let sent = op(
        "sessionEncrypt",
        json!({ "storageKey": storage_key(), "session": out["session"], "plaintext": "hello" }),
    );
    assert_eq!(
        sent["message"]["type"], 0,
        "a session's first message carries what starts it"
    );

    let first_id = op("messageSessionId", json!({ "message": sent["message"] }));
    assert_eq!(first_id["sessionId"], out["sessionId"]);

    let accepted = op(
        "sessionInbound",
        json!({ "storageKey": storage_key(), "account": bob.account, "identityKey": alice.identity, "message": sent["message"] }),
    );
    assert_eq!(accepted["plaintext"], "hello");
    assert_eq!(accepted["sessionId"], out["sessionId"]);
    bob.account = accepted["account"].as_str().unwrap().into();

    // the one-time key that started it is spent
    let keys = op(
        "accountKeys",
        json!({ "storageKey": storage_key(), "account": bob.account }),
    );
    assert_eq!(keys["storedOneTimeKeys"], 4);

    let reply = op(
        "sessionEncrypt",
        json!({ "storageKey": storage_key(), "session": accepted["session"], "plaintext": "hi, Muffin" }),
    );
    let read = op(
        "sessionDecrypt",
        json!({ "storageKey": storage_key(), "session": sent["session"], "message": reply["message"] }),
    );
    assert_eq!(read["plaintext"], "hi, Muffin");
}

#[test]
fn a_thread_reads_on_a_device_let_in_later() {
    let thread = op("threadNew", json!({ "storageKey": storage_key() }));
    let mut outbound = thread["outbound"].clone();
    let mut stored = vec![];
    for i in 0..10 {
        let sealed = op(
            "threadEncrypt",
            json!({ "storageKey": storage_key(), "outbound": outbound, "plaintext": format!("m{i}") }),
        );
        assert_eq!(sealed["messageIndex"], i);
        assert_eq!(sealed["sessionId"], thread["sessionId"]);
        outbound = sealed["outbound"].clone();
        stored.push(sealed["ciphertext"].clone());
    }

    let phone = op(
        "threadInbound",
        json!({ "storageKey": storage_key(), "sessionKey": thread["sessionKey"] }),
    );
    let exported = op(
        "threadExport",
        json!({ "storageKey": storage_key(), "inbound": phone["inbound"] }),
    );
    let tablet = op(
        "threadImport",
        json!({ "storageKey": storage_key(), "exportedKey": exported["exportedKey"] }),
    );
    assert_eq!(tablet["firstKnownIndex"], 0);

    let mut inbound = tablet["inbound"].clone();
    for (i, ciphertext) in stored.iter().enumerate().rev() {
        let read = op(
            "threadDecrypt",
            json!({ "storageKey": storage_key(), "inbound": inbound, "ciphertext": ciphertext }),
        );
        assert_eq!(read["plaintext"], format!("m{i}"));
        assert_eq!(read["messageIndex"], i);
        inbound = read["inbound"].clone();
    }

    let later = op(
        "threadExport",
        json!({ "storageKey": storage_key(), "inbound": phone["inbound"], "fromIndex": 5 }),
    );
    let late = op(
        "threadImport",
        json!({ "storageKey": storage_key(), "exportedKey": later["exportedKey"] }),
    );
    assert_eq!(late["firstKnownIndex"], 5);
    assert_eq!(
        fails(
            "threadDecrypt",
            json!({ "storageKey": storage_key(), "inbound": late["inbound"], "ciphertext": stored[4] })
        ),
        "decrypt_failed"
    );
}

/// The old device and the new one compare a code, then the old one vouches for
/// the new one's keys: a MAC over the comparison, and a signature anyone can check.
#[test]
fn an_old_device_vouches_for_a_new_one() {
    let (old, new) = (device(), device());
    let one = op("comparisonStart", json!({}));
    let two = op("comparisonStart", json!({}));
    op(
        "comparisonEstablish",
        json!({ "comparison": one["comparison"], "publicKey": two["publicKey"] }),
    );
    op(
        "comparisonEstablish",
        json!({ "comparison": two["comparison"], "publicKey": one["publicKey"] }),
    );

    let code_one = op(
        "comparisonCode",
        json!({ "comparison": one["comparison"], "info": "add a device" }),
    );
    let code_two = op(
        "comparisonCode",
        json!({ "comparison": two["comparison"], "info": "add a device" }),
    );
    assert_eq!(code_one["decimals"], code_two["decimals"]);
    assert_eq!(code_one["emoji"].as_array().unwrap().len(), 7);

    // the new device sends its identity key with a MAC; the old one checks it
    let mac = op(
        "comparisonMac",
        json!({ "comparison": two["comparison"], "input": new.identity, "info": "identity" }),
    );
    let checked = op(
        "comparisonVerifyMac",
        json!({ "comparison": one["comparison"], "input": new.identity, "info": "identity", "mac": mac["mac"] }),
    );
    assert_eq!(checked["valid"], true);
    let swapped = op(
        "comparisonVerifyMac",
        json!({ "comparison": one["comparison"], "input": old.identity, "info": "identity", "mac": mac["mac"] }),
    );
    assert_eq!(swapped["valid"], false);

    // then signs it, so the other person's devices can see who let it in
    let signed = op(
        "accountSign",
        json!({ "storageKey": storage_key(), "account": old.account, "message": new.identity }),
    );
    let valid = op(
        "verifySignature",
        json!({ "signingKey": old.signing, "message": new.identity, "signature": signed["signature"] }),
    );
    assert_eq!(valid["valid"], true);
    let other = op(
        "verifySignature",
        json!({ "signingKey": old.signing, "message": old.identity, "signature": signed["signature"] }),
    );
    assert_eq!(other["valid"], false);

    assert_eq!(
        op("comparisonEnd", json!({ "comparison": one["comparison"] }))["ended"],
        true
    );
    assert_eq!(
        fails(
            "comparisonCode",
            json!({ "comparison": one["comparison"], "info": "x" })
        ),
        "no_comparison"
    );
    op("comparisonEnd", json!({ "comparison": two["comparison"] }));
}

/// The side that would see the other's key first gets its commitment before
/// that: a key picked afterwards, to grind the short code into a match, is
/// refused, and the comparison has to start over.
#[test]
fn a_key_must_be_the_one_committed_to() {
    let starter = op("comparisonStart", json!({}));
    let accepter = op("comparisonStart", json!({}));
    let relay = op("comparisonStart", json!({}));

    // the accepter's own key, with its commitment: fine
    op(
        "comparisonEstablish",
        json!({ "comparison": starter["comparison"], "publicKey": accepter["publicKey"], "commitment": accepter["commitment"] }),
    );

    // a relay's key under the accepter's commitment: refused, and gone
    let other = op("comparisonStart", json!({}));
    assert_eq!(
        fails(
            "comparisonEstablish",
            json!({ "comparison": other["comparison"], "publicKey": relay["publicKey"], "commitment": accepter["commitment"] }),
        ),
        "commitment_mismatch"
    );
    assert_eq!(
        fails(
            "comparisonCode",
            json!({ "comparison": other["comparison"], "info": "x" })
        ),
        "no_comparison"
    );

    for each in [&starter, &accepter, &relay] {
        op("comparisonEnd", json!({ "comparison": each["comparison"] }));
    }
}

#[test]
fn a_code_needs_an_established_comparison() {
    let started = op("comparisonStart", json!({}));
    assert_eq!(
        fails(
            "comparisonCode",
            json!({ "comparison": started["comparison"], "info": "x" })
        ),
        "no_comparison"
    );
    op(
        "comparisonEnd",
        json!({ "comparison": started["comparison"] }),
    );
}

#[test]
fn a_fingerprint_fits_a_link_and_depends_on_the_context() {
    let device = device();
    let keys = json!({ "identityKey": device.identity, "signingKey": device.signing });
    let mut args = keys.clone();
    args["context"] = json!("an app");
    let one = op("fingerprint", args.clone());
    assert_eq!(
        op("fingerprint", args)["fingerprint"],
        one["fingerprint"],
        "stable"
    );
    let text = one["fingerprint"].as_str().unwrap();
    assert_eq!(text.len(), 22);
    assert!(
        text.chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_'),
        "URL-safe: {text}"
    );

    let mut other = keys;
    other["context"] = json!("another app");
    assert_ne!(op("fingerprint", other)["fingerprint"], one["fingerprint"]);
}

#[test]
fn a_note_opens_with_its_key_and_context() {
    let key = op("noteKey", json!({}))["key"].clone();
    let sealed = op(
        "noteSeal",
        json!({ "key": key, "context": "notes", "plaintext": "left knee" }),
    );
    let opened = op(
        "noteOpen",
        json!({ "key": key, "context": "notes", "sealed": sealed["sealed"] }),
    );
    assert_eq!(opened["plaintext"], "left knee");
    assert_eq!(
        fails(
            "noteOpen",
            json!({ "key": key, "context": "other", "sealed": sealed["sealed"] })
        ),
        "wont_open"
    );
}

/// The whole report path: franked inside a thread message, opened by the
/// recipient, and checkable by a server with a stock HMAC of the words.
#[test]
fn a_reported_message_checks_out_and_an_altered_one_doesnt() {
    let franked = op("frank", json!({ "plaintext": "see you Thursday" }));
    let thread = op("threadNew", json!({ "storageKey": storage_key() }));
    let sealed = op(
        "threadEncrypt",
        json!({ "storageKey": storage_key(), "outbound": thread["outbound"], "plaintext": franked["inner"] }),
    );

    let reader = op(
        "threadInbound",
        json!({ "storageKey": storage_key(), "sessionKey": thread["sessionKey"] }),
    );
    let read = op(
        "threadDecrypt",
        json!({ "storageKey": storage_key(), "inbound": reader["inbound"], "ciphertext": sealed["ciphertext"] }),
    );
    let opened = op(
        "frankOpen",
        json!({ "inner": read["plaintext"], "commitment": franked["commitment"] }),
    );
    assert_eq!(opened["plaintext"], "see you Thursday");

    let report = |words: &str| {
        op("frankVerify", json!({ "frankingKey": opened["frankingKey"], "plaintext": words, "commitment": franked["commitment"] }))["valid"].clone()
    };
    assert_eq!(report("see you Thursday"), true);
    assert_eq!(report("see you never"), false);

    let other = op("frank", json!({ "plaintext": "other words" }));
    assert_eq!(
        fails(
            "frankOpen",
            json!({ "inner": read["plaintext"], "commitment": other["commitment"] })
        ),
        "commitment_mismatch"
    );
}

#[test]
fn state_wont_open_under_another_storage_key() {
    let device = device();
    let wrong = STANDARD.encode([1u8; 32]);
    assert_eq!(
        fails(
            "accountKeys",
            json!({ "storageKey": wrong, "account": device.account })
        ),
        "wrong_storage_key"
    );
}

#[test]
fn a_device_holds_at_most_fifty_one_time_keys() {
    let device = device();
    assert_eq!(
        fails(
            "accountNew",
            json!({ "storageKey": storage_key(), "oneTimeKeys": 51 })
        ),
        "bad_input"
    );
    let more = op(
        "accountOneTimeKeys",
        json!({ "storageKey": storage_key(), "account": device.account, "count": 45 }),
    );
    assert_eq!(more["oneTimeKeys"].as_array().unwrap().len(), 45);
    assert_eq!(
        fails(
            "accountOneTimeKeys",
            json!({ "storageKey": storage_key(), "account": more["account"], "count": 1 })
        ),
        "bad_input"
    );
}

/// A count that can't fit, or would wrap a 32-bit device's arithmetic past the
/// limit, is refused rather than truncated.
#[test]
fn a_huge_one_time_key_count_is_refused() {
    let device = device();
    for count in [u64::MAX, u64::from(u32::MAX), 1u64 << 32] {
        assert_eq!(
            fails(
                "accountOneTimeKeys",
                json!({ "storageKey": storage_key(), "account": device.account, "count": count })
            ),
            "bad_input"
        );
        assert_eq!(
            fails(
                "accountNew",
                json!({ "storageKey": storage_key(), "oneTimeKeys": count })
            ),
            "bad_input"
        );
    }
}

#[test]
fn the_fallback_key_can_be_replaced() {
    let device = device();
    let one = op(
        "accountFallbackKey",
        json!({ "storageKey": storage_key(), "account": device.account }),
    );
    let two = op(
        "accountFallbackKey",
        json!({ "storageKey": storage_key(), "account": one["account"] }),
    );
    assert_ne!(one["fallbackKey"]["key"], two["fallbackKey"]["key"]);
}

#[test]
fn missing_or_bad_arguments_name_themselves() {
    let mut args = json!({ "op": "noteSeal", "key": "nope", "context": "x", "plaintext": "y" });
    let error = call(&args).unwrap_err();
    assert_eq!(error.code, "bad_input");
    assert!(error.message.contains("key"), "{}", error.message);
    args["op"] = json!("sessionEncrypt");
    assert!(
        call(&args)
            .unwrap_err()
            .message
            .contains("session is missing")
    );
}
