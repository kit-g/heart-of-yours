import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Whether the app may talk to heart-api at all — the one question every
/// remote leg asks before it dials out.
///
/// Held as a single object shared by reference rather than a flag on each
/// state class, so the rule is decided in one place and consulted everywhere
/// with the same answer. Two things decide it:
///
/// - [account] — [Auth]'s answer: there is an account behind the session.
///   While the session is anonymous the answer is no: without an account
///   nothing leaves the phone, and an anonymous token reaching the server is a
///   bug. Every state class then behaves as if it were permanently offline —
///   local writes land, remote ones are skipped, and what is skipped is left
///   unsynced for whenever an account arrives.
/// - [replaying] — `Upsync`'s answer: that account has just arrived, and the
///   store the session built up is still being replayed into it. Until the
///   replay completes the incidental remote legs stay closed too, or the
///   launch-time sweeps (`syncPendingWorkouts`, `pushPending`, the pulls) would
///   post the same rows out of order and pull the server's view over a mirror
///   that has not reached it yet. The replay itself talks to the server
///   directly, and opens the leg when it is done.
///
/// Allowed by default, so a class built without an [Auth] behind it (tests,
/// tools) keeps its remote leg.
class RemoteAccess {
  /// An account stands behind the session.
  bool account;

  /// The session's store is being replayed into that account.
  bool replaying;

  new({bool allowed = true}) : account = allowed, replaying = false;

  bool get allowed => account && !replaying;

  static RemoteAccess of(BuildContext context) {
    return Provider.of<RemoteAccess>(context, listen: false);
  }
}
