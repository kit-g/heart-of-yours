//! End-to-end encryption between devices, on vodozemac (Olm and Megolm).
//!
//! It knows nothing about any app, server or store. The caller keeps every
//! piece of state, moves the bytes, and names its own contexts. State goes in
//! and comes back sealed under a key the caller holds, usually in the Keychain
//! or Keystore.
//!
//! [`ops::call`] is the whole surface, reached from Dart through one C entry
//! point in [`ffi`]: a JSON object naming an operation goes in, a JSON object
//! comes out. Bytes travel as base64.

pub mod franking;
pub mod notes;
pub mod ops;

mod comparisons;
mod encoding;
mod ffi;

/// Fills a fixed-size array from the OS's random source.
pub(crate) fn random<const N: usize>() -> [u8; N] {
    let mut bytes = [0u8; N];
    getrandom::fill(&mut bytes).expect("the OS has no random source");
    bytes
}
