//! Every operation, by name. JSON in, JSON out, nothing kept between calls
//! except running code comparisons: the caller stores the state each call
//! returns, and passes it back in on the next.
//!
//! Field names are camelCase on both sides. Bytes are base64. State (an
//! account, a session, a thread key) is sealed under `storageKey`, 32 bytes
//! that the caller keeps out of backups.

use serde_json::{Value, json};
use vodozemac::megolm::{
    ExportedSessionKey, GroupSession, GroupSessionPickle, InboundGroupSession,
    InboundGroupSessionPickle, MegolmMessage, SessionConfig as ThreadConfig, SessionKey,
};
use vodozemac::olm::{Account, AccountPickle, OlmMessage, Session, SessionConfig, SessionPickle};
use vodozemac::{Curve25519PublicKey, Ed25519PublicKey, Ed25519Signature, KeyId};

use crate::comparisons::{self, Comparison};
use crate::encoding::{decode, decode_key, encode, encode_url};
use crate::{franking, notes};

/// A device holds at most this many unused one-time keys at once.
pub const MAX_ONE_TIME_KEYS: usize = 50;

#[derive(Debug, PartialEq, Eq)]
pub struct OpError {
    pub code: &'static str,
    pub message: String,
}

impl OpError {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

type Result<T> = std::result::Result<T, OpError>;

fn bad_input(message: impl Into<String>) -> OpError {
    OpError::new("bad_input", message)
}

/// Reads one operation's arguments.
struct Args<'a>(&'a Value);

impl Args<'_> {
    fn str(&self, name: &str) -> Result<&str> {
        self.0[name]
            .as_str()
            .ok_or_else(|| bad_input(format!("{name} is missing")))
    }

    fn bytes(&self, name: &str) -> Result<Vec<u8>> {
        decode(self.str(name)?).ok_or_else(|| bad_input(format!("{name} isn't base64")))
    }

    fn key(&self, name: &str) -> Result<[u8; 32]> {
        decode_key(self.str(name)?)
            .ok_or_else(|| bad_input(format!("{name} isn't 32 bytes of base64")))
    }

    fn count(&self, name: &str) -> Result<Option<u64>> {
        match &self.0[name] {
            Value::Null => Ok(None),
            value => value
                .as_u64()
                .map(Some)
                .ok_or_else(|| bad_input(format!("{name} isn't a count"))),
        }
    }

    fn storage_key(&self) -> Result<[u8; 32]> {
        self.key("storageKey")
    }

    fn account(&self) -> Result<Account> {
        let pickle = AccountPickle::from_encrypted(self.str("account")?, &self.storage_key()?)
            .map_err(unsealed)?;
        Ok(Account::from_pickle(pickle))
    }

    fn session(&self) -> Result<Session> {
        let pickle = SessionPickle::from_encrypted(self.str("session")?, &self.storage_key()?)
            .map_err(unsealed)?;
        Ok(Session::from_pickle(pickle))
    }

    fn outbound(&self) -> Result<GroupSession> {
        let pickle =
            GroupSessionPickle::from_encrypted(self.str("outbound")?, &self.storage_key()?)
                .map_err(unsealed)?;
        Ok(GroupSession::from_pickle(pickle))
    }

    fn inbound(&self) -> Result<InboundGroupSession> {
        let pickle =
            InboundGroupSessionPickle::from_encrypted(self.str("inbound")?, &self.storage_key()?)
                .map_err(unsealed)?;
        Ok(InboundGroupSession::from_pickle(pickle))
    }

    fn curve_key(&self, name: &str) -> Result<Curve25519PublicKey> {
        Curve25519PublicKey::from_base64(self.str(name)?)
            .map_err(|e| bad_input(format!("{name}: {e}")))
    }

    fn olm_message(&self) -> Result<OlmMessage> {
        let message = &self.0["message"];
        let kind = message["type"]
            .as_u64()
            .ok_or_else(|| bad_input("message.type is missing"))? as usize;
        let body = message["body"]
            .as_str()
            .and_then(decode)
            .ok_or_else(|| bad_input("message.body isn't base64"))?;
        OlmMessage::from_parts(kind, &body).map_err(|e| bad_input(format!("message: {e}")))
    }
}

fn unsealed(e: impl std::fmt::Display) -> OpError {
    OpError::new(
        "wrong_storage_key",
        format!("state won't open with this storage key: {e}"),
    )
}

fn text(bytes: Vec<u8>) -> Result<String> {
    String::from_utf8(bytes).map_err(|_| OpError::new("not_text", "the plaintext isn't UTF-8"))
}

fn keys_json(keys: impl IntoIterator<Item = (KeyId, Curve25519PublicKey)>) -> Value {
    let mut keys: Vec<_> = keys
        .into_iter()
        .map(|(id, key)| (id.to_base64(), key.to_base64()))
        .collect();
    keys.sort();
    keys.into_iter()
        .map(|(id, key)| json!({ "id": id, "key": key }))
        .collect()
}

fn olm_json(message: &OlmMessage) -> Value {
    let (kind, body) = message.to_parts();
    json!({ "type": kind, "body": encode(&body) })
}

fn comparison_id(args: &Args) -> Result<u64> {
    args.count("comparison")?
        .ok_or_else(|| bad_input("comparison is missing"))
}

/// [requested] one-time keys on top of [stored], or `bad_input` when the
/// device would hold more than [MAX_ONE_TIME_KEYS]. Compared without adding,
/// and without narrowing first, so no count wraps past the limit on a 32-bit
/// device.
fn one_time_key_count(requested: u64, stored: usize) -> Result<usize> {
    let room = MAX_ONE_TIME_KEYS.saturating_sub(stored);
    match usize::try_from(requested) {
        Ok(count) if count <= room => Ok(count),
        _ => Err(bad_input(format!(
            "a device holds at most {MAX_ONE_TIME_KEYS} one-time keys"
        ))),
    }
}

/// Runs one operation.
pub fn call(input: &Value) -> Result<Value> {
    let args = Args(input);
    match args.str("op")? {
        // ---- a device's account: its identity, signing key and one-time keys ----
        "accountNew" => {
            let storage_key = args.storage_key()?;
            let count = one_time_key_count(args.count("oneTimeKeys")?.unwrap_or(20), 0)?;
            let mut account = Account::new();
            account.generate_one_time_keys(count);
            account.generate_fallback_key();
            let one_time_keys = keys_json(account.one_time_keys());
            let fallback_key = keys_json(account.fallback_key());
            account.mark_keys_as_published();
            Ok(json!({
                "account": account.pickle().encrypt(&storage_key),
                "identityKey": account.curve25519_key().to_base64(),
                "signingKey": account.ed25519_key().to_base64(),
                "oneTimeKeys": one_time_keys,
                "fallbackKey": fallback_key[0],
            }))
        }
        "accountKeys" => {
            let account = args.account()?;
            Ok(json!({
                "identityKey": account.curve25519_key().to_base64(),
                "signingKey": account.ed25519_key().to_base64(),
                "storedOneTimeKeys": account.stored_one_time_key_count(),
            }))
        }
        "accountOneTimeKeys" => {
            let mut account = args.account()?;
            let requested = args
                .count("count")?
                .ok_or_else(|| bad_input("count is missing"))?;
            let count = one_time_key_count(requested, account.stored_one_time_key_count())?;
            account.generate_one_time_keys(count);
            let one_time_keys = keys_json(account.one_time_keys());
            account.mark_keys_as_published();
            Ok(
                json!({ "account": account.pickle().encrypt(&args.storage_key()?), "oneTimeKeys": one_time_keys }),
            )
        }
        "accountFallbackKey" => {
            let mut account = args.account()?;
            account.generate_fallback_key();
            let fallback_key = keys_json(account.fallback_key());
            account.mark_keys_as_published();
            Ok(
                json!({ "account": account.pickle().encrypt(&args.storage_key()?), "fallbackKey": fallback_key[0] }),
            )
        }
        "accountSign" => {
            let account = args.account()?;
            Ok(json!({ "signature": account.sign(args.str("message")?).to_base64() }))
        }
        "verifySignature" => {
            let key = Ed25519PublicKey::from_base64(args.str("signingKey")?)
                .map_err(|e| bad_input(e.to_string()))?;
            let signature = Ed25519Signature::from_base64(args.str("signature")?)
                .map_err(|e| bad_input(e.to_string()))?;
            Ok(json!({ "valid": key.verify(args.str("message")?.as_bytes(), &signature).is_ok() }))
        }

        // ---- a pairwise session between two devices ----
        "sessionOutbound" => {
            let account = args.account()?;
            let session = account
                .create_outbound_session(
                    SessionConfig::version_1(),
                    args.curve_key("identityKey")?,
                    args.curve_key("oneTimeKey")?,
                )
                .map_err(|e| OpError::new("session_failed", e.to_string()))?;
            Ok(json!({
                "session": session.pickle().encrypt(&args.storage_key()?),
                "sessionId": session.session_id(),
            }))
        }
        "sessionInbound" => {
            let mut account = args.account()?;
            let OlmMessage::PreKey(message) = args.olm_message()? else {
                return Err(OpError::new(
                    "not_first_message",
                    "only a session's first message starts it",
                ));
            };
            let created = account
                .create_inbound_session(
                    SessionConfig::version_1(),
                    args.curve_key("identityKey")?,
                    &message,
                )
                .map_err(|e| OpError::new("session_failed", e.to_string()))?;
            let storage_key = args.storage_key()?;
            Ok(json!({
                "account": account.pickle().encrypt(&storage_key),
                "session": created.session.pickle().encrypt(&storage_key),
                "sessionId": created.session.session_id(),
                "plaintext": text(created.plaintext)?,
            }))
        }
        "sessionEncrypt" => {
            let mut session = args.session()?;
            let message = session
                .encrypt(args.str("plaintext")?)
                .map_err(|e| OpError::new("encrypt_failed", e.to_string()))?;
            Ok(
                json!({ "session": session.pickle().encrypt(&args.storage_key()?), "message": olm_json(&message) }),
            )
        }
        "sessionDecrypt" => {
            let mut session = args.session()?;
            let plain = session
                .decrypt(&args.olm_message()?)
                .map_err(|e| OpError::new("decrypt_failed", e.to_string()))?;
            Ok(
                json!({ "session": session.pickle().encrypt(&args.storage_key()?), "plaintext": text(plain)? }),
            )
        }
        "messageSessionId" => {
            let session_id = match args.olm_message()? {
                OlmMessage::PreKey(message) => Value::from(message.session_id()),
                OlmMessage::Normal(_) => Value::Null,
            };
            Ok(json!({ "sessionId": session_id }))
        }

        // ---- a stored thread: one copy, readable by every device holding its key ----
        "threadNew" => {
            let thread = GroupSession::new(ThreadConfig::version_1());
            Ok(json!({
                "outbound": thread.pickle().encrypt(&args.storage_key()?),
                "sessionId": thread.session_id(),
                "sessionKey": thread.session_key().to_base64(),
            }))
        }
        "threadEncrypt" => {
            let mut thread = args.outbound()?;
            let index = thread.message_index();
            let message = thread.encrypt(args.str("plaintext")?);
            Ok(json!({
                "outbound": thread.pickle().encrypt(&args.storage_key()?),
                "ciphertext": message.to_base64(),
                "sessionId": thread.session_id(),
                "messageIndex": index,
            }))
        }
        "threadInbound" => {
            let key = SessionKey::from_base64(args.str("sessionKey")?)
                .map_err(|e| bad_input(e.to_string()))?;
            let thread = InboundGroupSession::new(&key, ThreadConfig::version_1());
            inbound_json(&thread, &args.storage_key()?)
        }
        "threadImport" => {
            let key = ExportedSessionKey::from_base64(args.str("exportedKey")?)
                .map_err(|e| bad_input(e.to_string()))?;
            let thread = InboundGroupSession::import(&key, ThreadConfig::version_1());
            inbound_json(&thread, &args.storage_key()?)
        }
        "threadExport" => {
            let mut thread = args.inbound()?;
            let index = match args.count("fromIndex")? {
                Some(index) => {
                    u32::try_from(index).map_err(|_| bad_input("fromIndex is too large"))?
                }
                None => thread.first_known_index(),
            };
            let exported = thread
                .export_at(index)
                .ok_or_else(|| OpError::new("not_known", "this key doesn't reach back that far"))?;
            Ok(json!({ "exportedKey": exported.to_base64() }))
        }
        "threadDecrypt" => {
            let mut thread = args.inbound()?;
            let message = MegolmMessage::from_base64(args.str("ciphertext")?)
                .map_err(|e| bad_input(e.to_string()))?;
            let decrypted = thread
                .decrypt(&message)
                .map_err(|e| OpError::new("decrypt_failed", e.to_string()))?;
            Ok(json!({
                "inbound": thread.pickle().encrypt(&args.storage_key()?),
                "plaintext": text(decrypted.plaintext)?,
                "messageIndex": decrypted.message_index,
                "sessionId": thread.session_id(),
            }))
        }

        // ---- comparing a code, to know no one sits between two devices ----
        "comparisonStart" => {
            let (id, public_key) = comparisons::start().ok_or_else(|| {
                OpError::new(
                    "too_many_comparisons",
                    format!(
                        "at most {} comparisons run at once",
                        comparisons::MAX_RUNNING
                    ),
                )
            })?;
            let commitment = comparisons::commitment(
                &Curve25519PublicKey::from_base64(&public_key).expect("its own key reads back"),
            );
            Ok(json!({
                "comparison": id,
                "publicKey": public_key,
                "commitment": encode(&commitment),
            }))
        }
        "comparisonEstablish" => {
            let id = comparison_id(&args)?;
            let their_key = args.curve_key("publicKey")?;
            // the side that showed its key first holds the other's commitment,
            // made before that side could see it: a key chosen afterwards to
            // grind the code into a match doesn't fit it
            if let Value::String(_) = &input["commitment"] {
                let expected = args.bytes("commitment")?;
                if expected != comparisons::commitment(&their_key) {
                    comparisons::end(id);
                    return Err(OpError::new(
                        "commitment_mismatch",
                        "their key isn't the one they committed to: start over",
                    ));
                }
            }
            match comparisons::take(id) {
                Some(Comparison::Started(sas)) => {
                    let established = sas
                        .diffie_hellman(their_key)
                        .map_err(|e| OpError::new("comparison_failed", e.to_string()))?;
                    comparisons::put(id, Comparison::Established(established));
                    Ok(json!({}))
                }
                Some(established) => {
                    comparisons::put(id, established);
                    Err(OpError::new(
                        "comparison_state",
                        "this comparison is already established",
                    ))
                }
                None => Err(OpError::new(
                    "no_comparison",
                    "no comparison is running with this id",
                )),
            }
        }
        "comparisonCode" => {
            let info = args.str("info")?;
            let (decimals, emoji) = comparisons::with_established(comparison_id(&args)?, |sas| {
                let bytes = sas.bytes(info);
                (bytes.decimals(), bytes.emoji_indices())
            })
            .ok_or_else(no_established)?;
            Ok(json!({ "decimals": [decimals.0, decimals.1, decimals.2], "emoji": emoji }))
        }
        "comparisonMac" => {
            let (input, info) = (args.str("input")?, args.str("info")?);
            let mac = comparisons::with_established(comparison_id(&args)?, |sas| {
                sas.calculate_mac(input, info).to_base64()
            })
            .ok_or_else(no_established)?;
            Ok(json!({ "mac": mac }))
        }
        "comparisonVerifyMac" => {
            let (input, info) = (args.str("input")?, args.str("info")?);
            let mac = vodozemac::sas::Mac::from_base64(args.str("mac")?)
                .map_err(|e| bad_input(e.to_string()))?;
            let valid = comparisons::with_established(comparison_id(&args)?, |sas| {
                sas.verify_mac(input, info, &mac).is_ok()
            })
            .ok_or_else(no_established)?;
            Ok(json!({ "valid": valid }))
        }
        "comparisonEnd" => Ok(json!({ "ended": comparisons::end(comparison_id(&args)?) })),

        // ---- a fingerprint of a device's keys, short enough to put in a link ----
        "fingerprint" => {
            let context = args.str("context")?;
            let identity = args.curve_key("identityKey")?;
            let signing = Ed25519PublicKey::from_base64(args.str("signingKey")?)
                .map_err(|e| bad_input(e.to_string()))?;
            let digest = fingerprint(context, &identity, &signing);
            Ok(json!({ "fingerprint": encode_url(&digest) }))
        }

        // ---- sealing to oneself ----
        "noteKey" => Ok(json!({ "key": encode(&notes::new_key()) })),
        "noteSeal" => {
            let sealed = notes::seal(
                &args.key("key")?,
                args.str("context")?,
                args.str("plaintext")?.as_bytes(),
            );
            Ok(json!({ "sealed": encode(&sealed) }))
        }
        "noteOpen" => {
            let plain = notes::unseal(
                &args.key("key")?,
                args.str("context")?,
                &args.bytes("sealed")?,
            )
            .ok_or_else(|| {
                OpError::new("wont_open", "wrong key or context, or the note was altered")
            })?;
            Ok(json!({ "plaintext": text(plain)? }))
        }

        // ---- franking: proving later what was said ----
        "frank" => {
            let franked = franking::frank(args.str("plaintext")?);
            Ok(json!({ "inner": franked.inner, "commitment": encode(&franked.commitment) }))
        }
        "frankOpen" => {
            let opened = franking::open(args.str("inner")?, &args.bytes("commitment")?).map_err(
                |e| match e {
                    franking::OpenError::Malformed => {
                        OpError::new("not_franked", "this isn't a franked message")
                    }
                    franking::OpenError::CommitmentMismatch => OpError::new(
                        "commitment_mismatch",
                        "the words don't match what the sender committed to",
                    ),
                },
            )?;
            Ok(json!({ "plaintext": opened.text, "frankingKey": encode(&opened.key) }))
        }
        "frankVerify" => {
            let valid = franking::verify(
                &args.key("frankingKey")?,
                args.str("plaintext")?,
                &args.bytes("commitment")?,
            );
            Ok(json!({ "valid": valid }))
        }

        other => Err(OpError::new(
            "unknown_op",
            format!("no operation called {other}"),
        )),
    }
}

fn no_established() -> OpError {
    OpError::new("no_comparison", "no established comparison with this id")
}

fn inbound_json(thread: &InboundGroupSession, storage_key: &[u8; 32]) -> Result<Value> {
    Ok(json!({
        "inbound": thread.pickle().encrypt(storage_key),
        "sessionId": thread.session_id(),
        "firstKnownIndex": thread.first_known_index(),
    }))
}

/// 16 bytes of HMAC-SHA256 over both public keys, under the caller's context,
/// so the same device gives different fingerprints in different apps.
fn fingerprint(
    context: &str,
    identity: &Curve25519PublicKey,
    signing: &Ed25519PublicKey,
) -> [u8; 16] {
    use hmac::{Hmac, KeyInit, Mac};
    let mut mac = <Hmac<sha2::Sha256> as KeyInit>::new_from_slice(context.as_bytes())
        .expect("any key length");
    mac.update(identity.as_bytes());
    mac.update(signing.as_bytes());
    let digest = mac.finalize().into_bytes();
    digest[..16].try_into().expect("16 of 32 bytes")
}
