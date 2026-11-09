//! Sealing to oneself: something only the holder of a key can read, such as a
//! note one person keeps across their own devices. The key moves between those
//! devices inside a pairwise session.
//!
//! XChaCha20-Poly1305 with a random 24-byte nonce, so random nonces never need
//! counting. The caller's context is bound in as associated data: a note sealed
//! for one purpose won't open as another.

use chacha20poly1305::aead::Aead;
use chacha20poly1305::aead::Payload;
use chacha20poly1305::{KeyInit, XChaCha20Poly1305, XNonce};

const NONCE: usize = 24;

pub fn new_key() -> [u8; 32] {
    crate::random()
}

pub fn seal(key: &[u8; 32], context: &str, plain: &[u8]) -> Vec<u8> {
    let nonce: [u8; NONCE] = crate::random();
    let cipher = XChaCha20Poly1305::new_from_slice(key).expect("a 32-byte key");
    let sealed = cipher
        .encrypt(
            &XNonce::from(nonce),
            Payload {
                msg: plain,
                aad: context.as_bytes(),
            },
        )
        .expect("a note fits");
    [nonce.as_slice(), &sealed].concat()
}

/// `None` for a wrong key, a wrong context, or anything altered.
pub fn unseal(key: &[u8; 32], context: &str, sealed: &[u8]) -> Option<Vec<u8>> {
    if sealed.len() < NONCE {
        return None;
    }
    let (nonce, body) = sealed.split_at(NONCE);
    let nonce: [u8; NONCE] = nonce.try_into().ok()?;
    let cipher = XChaCha20Poly1305::new_from_slice(key).ok()?;
    cipher
        .decrypt(
            &XNonce::from(nonce),
            Payload {
                msg: body,
                aad: context.as_bytes(),
            },
        )
        .ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opens_with_the_key_and_context_only() {
        let key = new_key();
        let sealed = seal(&key, "notes", b"left knee, avoid deep flexion");
        assert_eq!(
            unseal(&key, "notes", &sealed).unwrap(),
            b"left knee, avoid deep flexion"
        );
        assert!(
            unseal(&new_key(), "notes", &sealed).is_none(),
            "another key"
        );
        assert!(unseal(&key, "drafts", &sealed).is_none(), "another context");
    }

    #[test]
    fn altered_or_short_input_fails() {
        let key = new_key();
        let mut sealed = seal(&key, "notes", b"x");
        *sealed.last_mut().unwrap() ^= 1;
        assert!(unseal(&key, "notes", &sealed).is_none());
        assert!(unseal(&key, "notes", &[1, 2, 3]).is_none());
    }

    #[test]
    fn the_same_words_seal_differently_each_time() {
        let key = new_key();
        assert_ne!(seal(&key, "notes", b"same"), seal(&key, "notes", b"same"));
    }
}
