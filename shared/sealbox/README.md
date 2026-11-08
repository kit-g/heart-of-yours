# sealbox

End-to-end encryption between devices, on [vodozemac](https://github.com/matrix-org/vodozemac)
(Olm and Megolm, Rust, Apache-2.0), through a binding of its own: one C function, JSON in and out.

It knows nothing about any app, server or store. The caller keeps every piece of state, moves the
bytes, and names its own contexts. It depends on nothing of Heart's and must stay that way, so it can
serve another app with a harsher threat model.

**It has had no outside review.** Don't describe it as safe for people at risk until it has.

## What's in it

- **Accounts:** a device's identity key, signing key, up to 50 one-time keys and a fallback key.
  Signing and checking signatures, so an old device can vouch for a new one.
- **Pairwise sessions** (Olm) between two devices: for moving keys, never for keeping history.
- **Stored threads** (Megolm): one copy of each message on a server, readable by every device holding
  the thread key, in any order and as often as needed. Keys export from any point, so a new device
  can catch up.
- **Comparing a code** (SAS): three numbers or seven emoji, the same on both screens unless someone
  sits between the devices, plus MACs to pass keys across once they match.
- **Fingerprints:** 22 URL-safe characters naming a device's keys under the caller's context, short
  enough for a link's fragment.
- **Notes:** sealing to oneself (XChaCha20-Poly1305), bound to a context.
- **Franking**, for reporting: the words go inside the encryption with a fresh key, and
  `HMAC-SHA256(key, words)` travels beside them as the commitment. A server that tags the commitment
  with sender, recipient and time can later check a report with a stock HMAC.

## Two ways to keep messages

The library offers both. Which one fits is the caller's choice, not the library's.

- **A stored thread.** One copy on the server, every device with the key can read it, again and
  again. A new device can be given the whole history. The cost: a stolen thread key opens every
  message it covers, including old ones the server still holds.
- **Per-device copies.** A pairwise message per device, whose key is used once and gone. Old messages
  are safer, and history lives only on the devices that received it.

Heart's coaching uses stored threads, so a coach's new tablet can read the whole conversation. An app
for people at greater risk would likely choose per-device copies.

## What a caller has to do

The library won't do these. Each one that can be shown is pinned by a test in
`rust/tests/obligations.rs`.

- **Refuse a thread message at a position already seen with different content.** A sender put back
  to an older state seals new words at a position it already used, and the library opens both.
  Keep `(sessionId, messageIndex)` of what was read.
- **Keep a counter in secure storage, and check it before sending.** State older than the counter was
  restored from a backup and reuses keys, so start over with new sessions and a new thread key.
- **Read pairwise messages in order.** Only a short run of skipped ones can be recovered, and each
  opens once.
- **Keep state and the storage key out of phone backups.** A restored phone is a new device.
- **Save what a call returns before acting on it.** State that isn't saved gets used twice.
- **Replace one-time keys as they're used,** keeping at most 50, and rotate the fallback key now and
  then.
- **End comparisons.** They live in memory between `Comparison.start()` and `end()`, and a restart
  abandons them.

## Building

`hook/build.dart` runs cargo for the target, or uses `prebuilt/<rust triple>/` if that holds a
library, for machines without Rust. Cargo inherits nothing from the build's environment, since
Xcode's `SDKROOT` breaks linking cargo's own build scripts. For Android it links with the NDK's clang,
found next to the C compiler the build hands every hook.

`rust/rust-toolchain.toml` pins Rust and lists every target, and rustup installs them on first use.
About 0.6 to 0.9 MB per architecture.

```sh
make test-sealbox   # cargo fmt, clippy and tests, then the Dart tests through the real library
```

`dart test` runs from inside the package: a test run from the workspace root builds native code only
for what the app depends on.
