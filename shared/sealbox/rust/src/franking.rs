//! Message franking: how a recipient can later prove what a sender wrote.
//!
//! The sender picks a fresh key per message, puts it inside the encryption
//! with the words, and sends `HMAC-SHA256(key, words)` beside the ciphertext as
//! the commitment. A server that tags the commitment with who sent it to whom,
//! and when, can later check a report: the reporter hands over the words and
//! the key, and both have to match what the server saw. The commitment is the
//! plain HMAC of the UTF-8 words, with nothing else mixed in, so any server
//! can check it with a stock HMAC.

use hmac::{Hmac, KeyInit, Mac};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

/// What goes inside the encryption: the words and the key that commits to them.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Franked {
    pub inner: String,
    pub commitment: [u8; 32],
}

/// What the recipient gets back on opening.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Opened {
    pub text: String,
    pub key: [u8; 32],
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OpenError {
    /// The decrypted bytes aren't a franked message.
    Malformed,
    /// The words don't match the commitment the server saw.
    CommitmentMismatch,
}

pub fn commitment(key: &[u8; 32], text: &str) -> [u8; 32] {
    let mut mac = <HmacSha256 as KeyInit>::new_from_slice(key).expect("HMAC takes any key length");
    mac.update(text.as_bytes());
    mac.finalize().into_bytes().into()
}

pub fn frank(text: &str) -> Franked {
    let key: [u8; 32] = crate::random();
    let inner = serde_json::json!({ "t": text, "k": crate::encoding::encode(&key) }).to_string();
    Franked {
        inner,
        commitment: commitment(&key, text),
    }
}

/// Opens what came out of the decryption, and checks it against the commitment
/// that travelled beside it. A sender who committed to other words is caught here.
pub fn open(inner: &str, expected: &[u8]) -> Result<Opened, OpenError> {
    let value: serde_json::Value = serde_json::from_str(inner).map_err(|_| OpenError::Malformed)?;
    let text = value["t"].as_str().ok_or(OpenError::Malformed)?.to_owned();
    let key = value["k"]
        .as_str()
        .and_then(crate::encoding::decode_key)
        .ok_or(OpenError::Malformed)?;
    if !verify(&key, &text, expected) {
        return Err(OpenError::CommitmentMismatch);
    }
    Ok(Opened { text, key })
}

/// That [text] under [key] gives [expected], compared in constant time.
pub fn verify(key: &[u8; 32], text: &str, expected: &[u8]) -> bool {
    let mut mac = <HmacSha256 as KeyInit>::new_from_slice(key).expect("HMAC takes any key length");
    mac.update(text.as_bytes());
    mac.verify_slice(expected).is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opens_what_was_franked() {
        let franked = frank("see you Thursday");
        let opened = open(&franked.inner, &franked.commitment).unwrap();
        assert_eq!(opened.text, "see you Thursday");
        assert!(verify(&opened.key, "see you Thursday", &franked.commitment));
    }

    #[test]
    fn a_sender_committing_to_other_words_is_caught_on_opening() {
        let real = frank("real words");
        let other = frank("other words");
        assert_eq!(
            open(&real.inner, &other.commitment),
            Err(OpenError::CommitmentMismatch)
        );
    }

    #[test]
    fn changed_words_dont_verify() {
        let franked = frank("you did well");
        let opened = open(&franked.inner, &franked.commitment).unwrap();
        assert!(!verify(&opened.key, "you did badly", &franked.commitment));
    }

    /// The commitment is a stock HMAC-SHA256, so a server can check it without
    /// this crate. RFC 4231 test case 2.
    #[test]
    fn the_commitment_is_plain_hmac_sha256() {
        let mut key = [0u8; 32];
        key[..4].copy_from_slice(b"Jefe");
        let mut mac = <HmacSha256 as KeyInit>::new_from_slice(b"Jefe").unwrap();
        mac.update(b"what do ya want for nothing?");
        let stock: [u8; 32] = mac.finalize().into_bytes().into();
        // a 4-byte key and the same key zero-padded to the block size are the same HMAC key
        assert_eq!(commitment(&key, "what do ya want for nothing?"), stock);
        assert_eq!(
            hex::encode(stock),
            "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
        );
    }

    #[test]
    fn garbage_is_malformed() {
        assert_eq!(open("not json", &[0; 32]), Err(OpenError::Malformed));
        assert_eq!(open(r#"{"t":"x"}"#, &[0; 32]), Err(OpenError::Malformed));
    }
}
