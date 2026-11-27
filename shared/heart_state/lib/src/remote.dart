import 'dart:async';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Whether the app may talk to heart-api at all — the one question every
/// remote leg asks before it dials out.
///
/// Held as a single object shared by reference rather than a flag on each
/// state class, so the rule is decided in one place and consulted everywhere
/// with the same answer. Four things decide it:
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
/// - [hasToken] — the client's answer: the account's token is on it. [Auth]
///   learns of an account before the app has its token — Firebase restores
///   the user from the device, the token is a round trip behind — and the
///   opening page dials out in between. Those requests left with no token
///   (heart-of-yours#336); asked, rather than set, so it can never disagree
///   with the headers themselves.
/// - [outdated] — the client's other answer: the server has refused this
///   build (426) and the app is showing the upgrade gate. Nothing it sends
///   from then on can be answered, and every request that tries is another
///   426 — another report, another redraw of the gate (#683). Asked, like
///   [hasToken], of the flag the client's hook sets, so there is one.
///
/// Allowed by default, so a class built without an [Auth] behind it (tests,
/// tools) keeps its remote leg.
class RemoteAccess {
  /// An account stands behind the session.
  bool account;

  /// The session's store is being replayed into that account.
  bool replaying;

  /// The client carries the account's token.
  final bool Function() hasToken;

  /// The server no longer serves this build.
  final bool Function() outdated;

  /// What a failed remote call says (#681), asked of the client that made it,
  /// as [hasToken] and [outdated] are: only it knows whether a failure it
  /// threw came with an answer, and of what status. Without a client, a
  /// failure is read by its type alone ([byType]).
  final RemoteFailure Function(Object error) _failures;

  new({
    bool allowed = true,
    bool Function()? hasToken,
    bool Function()? outdated,
    RemoteFailure Function(Object error)? failures,
  }) : account = allowed,
       replaying = false,
       hasToken = hasToken ?? _always,
       outdated = outdated ?? _never,
       _failures = failures ?? byType;

  bool get allowed => account && !replaying && hasToken() && !outdated();

  /// What [error], thrown by a remote call, says about asking again.
  RemoteFailure failureOf(Object error) => _failures(error);

  /// Whether [error] says the thing asked about is not there: a 404, named
  /// or not. For a delete, done; for a read, none.
  bool isGone(Object error) => failureOf(error) == .gone;

  /// [error] read by what this package can see of it: a [ServerRefusal] by
  /// its status, a parse failure as an answer this build cannot read, a
  /// deadline as passing, and anything else as no answer at all.
  static RemoteFailure byType(Object error) {
    return switch (error) {
      ServerRefusal(status: 404) => .gone,
      ServerRefusal(status: 429) => .transient,
      ServerRefusal() || UpgradeRequired() || AccountDeleted() => .answered,
      TimeoutException() => .transient,
      FormatException() || TypeError() || ArgumentError() => .answered,
      _ => .unanswered,
    };
  }

  static RemoteAccess of(BuildContext context) {
    return Provider.of<RemoteAccess>(context, listen: false);
  }
}

/// What a failed remote call says about asking again (#681): the one reading
/// of a failure, so a retry, a queue and a "check your connection" never
/// disagree about the same answer.
enum RemoteFailure {
  /// No answer at all: offline, a dropped connection. Asked again on the next
  /// run, never in a loop.
  unanswered,

  /// An answer that may be different next time: a server error, a throttle,
  /// a gateway that gave up, a deadline. Asked again later.
  transient,

  /// The thing asked about is not there: a 404, named or not. Gone, as far
  /// as a delete or a read about it goes.
  gone,

  /// Any other answer, which asking again gets again: a refusal, a 4xx with
  /// no code (a gateway's 401, 413), an answer this build cannot read.
  answered,
}

bool _always() => true;

bool _never() => false;
