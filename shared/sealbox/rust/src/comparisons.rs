//! Short authentication strings: two people compare a code to make sure no one
//! sits between their devices. A comparison lives only in memory, between
//! starting it and ending it. A restart abandons it, and the people start over.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, MutexGuard};

use vodozemac::sas::{EstablishedSas, Sas};

pub(crate) enum Comparison {
    Started(Sas),
    Established(EstablishedSas),
}

/// How many comparisons may be running at once. A comparison holds key
/// material, and one the caller never ended would otherwise stay for the life
/// of the process.
pub(crate) const MAX_RUNNING: usize = 16;

static NEXT: AtomicU64 = AtomicU64::new(1);
static RUNNING: Mutex<Option<HashMap<u64, Comparison>>> = Mutex::new(None);

fn running() -> MutexGuard<'static, Option<HashMap<u64, Comparison>>> {
    // a panic elsewhere can't poison a map of independent comparisons
    RUNNING
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// A new comparison, or `None` while [MAX_RUNNING] are already running.
pub(crate) fn start() -> Option<(u64, String)> {
    let mut running = running();
    let map = running.get_or_insert_with(HashMap::new);
    if map.len() >= MAX_RUNNING {
        return None;
    }
    let sas = Sas::new();
    let public_key = sas.public_key().to_base64();
    let id = NEXT.fetch_add(1, Ordering::Relaxed);
    map.insert(id, Comparison::Started(sas));
    Some((id, public_key))
}

/// What a side sends before it may see the other's key: SHA-256 over its own,
/// under a context of this crate's. Matrix's comparison does the same.
pub(crate) fn commitment(key: &vodozemac::Curve25519PublicKey) -> Vec<u8> {
    use sha2::{Digest, Sha256};
    let mut hash = Sha256::new();
    hash.update(b"sealbox-comparison-commitment");
    hash.update(key.as_bytes());
    hash.finalize().to_vec()
}

pub(crate) fn take(id: u64) -> Option<Comparison> {
    running().as_mut()?.remove(&id)
}

pub(crate) fn put(id: u64, comparison: Comparison) {
    running()
        .get_or_insert_with(HashMap::new)
        .insert(id, comparison);
}

pub(crate) fn with_established<T>(id: u64, f: impl FnOnce(&EstablishedSas) -> T) -> Option<T> {
    match running().as_ref()?.get(&id)? {
        Comparison::Established(sas) => Some(f(sas)),
        Comparison::Started(_) => None,
    }
}

pub(crate) fn end(id: u64) -> bool {
    take(id).is_some()
}
