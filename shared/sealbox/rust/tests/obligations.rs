//! What vodozemac does and doesn't do, pinned as tests. Each one is a reason
//! for a line in the README's list of what a caller has to do.

use vodozemac::Curve25519PublicKey;
use vodozemac::megolm::{
    GroupSession, GroupSessionPickle, InboundGroupSession, SessionConfig as ThreadConfig,
};
use vodozemac::olm::{Account, OlmMessage, Session, SessionConfig, SessionPickle};
use vodozemac::sas::Sas;

const STORAGE_KEY: [u8; 32] = [7; 32];

fn config() -> SessionConfig {
    SessionConfig::version_1()
}

fn one_time_key(account: &mut Account) -> Curve25519PublicKey {
    account.generate_one_time_keys(1);
    let key = *account.one_time_keys().values().next().unwrap();
    account.mark_keys_as_published();
    key
}

/// Two devices with a session each way, after one reply so both ratchets turned.
fn talking() -> (Session, Session) {
    let alice = Account::new();
    let mut bob = Account::new();
    let key = one_time_key(&mut bob);
    let mut a = alice
        .create_outbound_session(config(), bob.curve25519_key(), key)
        .unwrap();
    let OlmMessage::PreKey(first) = a.encrypt("hello").unwrap() else {
        panic!("a first message")
    };
    let mut b = bob
        .create_inbound_session(config(), alice.curve25519_key(), &first)
        .unwrap()
        .session;
    a.decrypt(&b.encrypt("hi").unwrap()).unwrap();
    (a, b)
}

/// *Refuse a thread message at a position already seen with different
/// content.* A sender put back to an older state seals new words at a
/// position it already used, and the library opens both.
#[test]
fn a_thread_position_used_twice_opens_twice() {
    let mut out = GroupSession::new(ThreadConfig::version_1());
    let mut reader = InboundGroupSession::new(&out.session_key(), ThreadConfig::version_1());
    let backup = out.pickle().encrypt(&STORAGE_KEY);
    let first = out.encrypt("first words");
    let mut rewound = GroupSession::from_pickle(
        GroupSessionPickle::from_encrypted(&backup, &STORAGE_KEY).unwrap(),
    );
    let second = rewound.encrypt("other words");

    let (a, b) = (
        reader.decrypt(&first).unwrap(),
        reader.decrypt(&second).unwrap(),
    );
    assert_eq!(a.message_index, b.message_index);
    assert_ne!(a.plaintext, b.plaintext);
}

/// *Keep a counter in secure storage, and check it before sending.* A device
/// restored from a backup reuses message keys it already used, and the other
/// side, already past that point, can't read what it sends.
#[test]
fn state_put_back_from_a_backup_reuses_keys() {
    let (mut a, mut b) = talking();
    // a send first, so the sending chain exists when the backup is taken: a
    // chain starts from a random key, and a backup before it would start afresh
    b.decrypt(&a.encrypt("before the backup").unwrap()).unwrap();
    let backup = a.pickle().encrypt(&STORAGE_KEY);
    let sent: Vec<_> = (0..5)
        .map(|i| a.encrypt(format!("after {i}")).unwrap())
        .collect();
    for message in &sent {
        b.decrypt(message).unwrap();
    }

    let mut restored =
        Session::from_pickle(SessionPickle::from_encrypted(&backup, &STORAGE_KEY).unwrap());
    let again = restored.encrypt("different words").unwrap();
    let (_, again) = again.to_parts();
    let (_, original) = sent[0].to_parts();
    assert_eq!(
        again[..37],
        original[..37],
        "the same ratchet key and position"
    );
    assert!(
        b.decrypt(&OlmMessage::from_parts(1, &again).unwrap())
            .is_err()
    );
}

/// The way out of stale or lost state: a new session from a fresh one-time key.
#[test]
fn a_new_session_starts_over() {
    let alice = Account::new();
    let mut bob = Account::new();
    let _old = one_time_key(&mut bob);
    let key = one_time_key(&mut bob);
    let mut a = alice
        .create_outbound_session(config(), bob.curve25519_key(), key)
        .unwrap();
    let OlmMessage::PreKey(first) = a.encrypt("new start").unwrap() else {
        panic!("a first message")
    };
    let created = bob
        .create_inbound_session(config(), alice.curve25519_key(), &first)
        .unwrap();
    assert_eq!(created.plaintext, b"new start");
}

/// *Read per-device items in order.* Out of order within a short window opens;
/// newest first over a longer stretch loses the older ones for good.
#[test]
fn pairwise_messages_tolerate_only_a_short_reordering() {
    let (mut a, mut b) = talking();
    let mut window: Vec<_> = (0..40)
        .map(|i| (i, a.encrypt(format!("w{i}")).unwrap()))
        .collect();
    window.reverse();
    for (i, message) in &window {
        assert_eq!(b.decrypt(message).unwrap(), format!("w{i}").as_bytes());
    }

    let mut long: Vec<_> = (0..50)
        .map(|i| a.encrypt(format!("l{i}")).unwrap())
        .collect();
    long.reverse();
    let opened = long
        .iter()
        .filter(|message| b.decrypt(message).is_ok())
        .count();
    assert!(opened < 50, "{opened} of 50 opened newest first");
}

/// A pairwise message opens once. Anything to read again belongs in a thread.
#[test]
fn a_pairwise_message_opens_once() {
    let (mut a, mut b) = talking();
    let message = a.encrypt("once").unwrap();
    b.decrypt(&message).unwrap();
    assert!(b.decrypt(&message).is_err());
}

/// A stored thread reads in any order, again and again, and a device let in
/// later with the key from the start reads all of it.
#[test]
fn a_stored_thread_reads_in_any_order_on_any_device() {
    let mut out = GroupSession::new(ThreadConfig::version_1());
    let mut phone = InboundGroupSession::new(&out.session_key(), ThreadConfig::version_1());
    let stored: Vec<_> = (0..300).map(|i| out.encrypt(format!("m{i}"))).collect();
    for (i, message) in stored.iter().enumerate().rev() {
        assert_eq!(
            phone.decrypt(message).unwrap().plaintext,
            format!("m{i}").as_bytes()
        );
    }
    for (i, message) in stored.iter().enumerate() {
        assert_eq!(
            phone.decrypt(message).unwrap().plaintext,
            format!("m{i}").as_bytes()
        );
    }

    let mut tablet =
        InboundGroupSession::import(&phone.export_at(0).unwrap(), ThreadConfig::version_1());
    assert_eq!(tablet.decrypt(&stored[0]).unwrap().plaintext, b"m0");

    // a key exported from a later point reads nothing before it
    let mut later =
        InboundGroupSession::import(&phone.export_at(200).unwrap(), ThreadConfig::version_1());
    assert!(later.decrypt(&stored[199]).is_err());
    assert!(later.decrypt(&stored[200]).is_ok());
}

/// A server in the middle that swaps the public keys gets different codes on
/// the two screens.
#[test]
fn a_swapped_key_shows_as_different_codes() {
    let info = "compare";
    let (one, two) = (Sas::new(), Sas::new());
    let (one_key, two_key) = (one.public_key(), two.public_key());
    let (one, two) = (
        one.diffie_hellman(two_key).unwrap(),
        two.diffie_hellman(one_key).unwrap(),
    );
    assert_eq!(one.bytes(info).decimals(), two.bytes(info).decimals());

    let (one, middle_a, two, middle_b) = (Sas::new(), Sas::new(), Sas::new(), Sas::new());
    let (one_key, two_key) = (one.public_key(), two.public_key());
    let one = one.diffie_hellman(middle_a.public_key()).unwrap();
    let two = two.diffie_hellman(middle_b.public_key()).unwrap();
    let _ = (
        middle_a.diffie_hellman(one_key).unwrap(),
        middle_b.diffie_hellman(two_key).unwrap(),
    );
    assert_ne!(one.bytes(info).decimals(), two.bytes(info).decimals());
}

/// With one-time keys gone, the fallback key still lets a session start.
#[test]
fn the_fallback_key_covers_running_out() {
    let mut bob = Account::new();
    bob.generate_fallback_key();
    let fallback = *bob.fallback_key().values().next().unwrap();
    bob.mark_keys_as_published();
    for sender in [Account::new(), Account::new()] {
        let mut session = sender
            .create_outbound_session(config(), bob.curve25519_key(), fallback)
            .unwrap();
        let OlmMessage::PreKey(first) = session.encrypt("via fallback").unwrap() else {
            panic!("a first message")
        };
        assert!(
            bob.create_inbound_session(config(), sender.curve25519_key(), &first)
                .is_ok()
        );
    }
}
