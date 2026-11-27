//! How bytes cross the boundary: base64, padded on the way out, either way in.

use base64::Engine;
use base64::engine::general_purpose::{STANDARD, STANDARD_NO_PAD, URL_SAFE_NO_PAD};

pub(crate) fn encode(bytes: &[u8]) -> String {
    STANDARD.encode(bytes)
}

/// For anything that rides in a URL, such as a fingerprint in a link's fragment.
pub(crate) fn encode_url(bytes: &[u8]) -> String {
    URL_SAFE_NO_PAD.encode(bytes)
}

pub(crate) fn decode(text: &str) -> Option<Vec<u8>> {
    STANDARD
        .decode(text)
        .or_else(|_| STANDARD_NO_PAD.decode(text))
        .ok()
}

pub(crate) fn decode_key(text: &str) -> Option<[u8; 32]> {
    decode(text)?.try_into().ok()
}
