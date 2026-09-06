import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Whether the app may talk to heart-api at all — the one question every
/// remote leg asks before it dials out.
///
/// Held as a single object shared by reference rather than a flag on each
/// state class, so the rule is decided in one place ([Auth]) and consulted
/// everywhere with the same answer. While the session is anonymous the answer
/// is no: without an account nothing leaves the phone, and an anonymous token
/// reaching the server is a bug. Every state class then behaves as if it were
/// permanently offline — local writes land, remote ones are skipped, and what
/// is skipped is left unsynced for whenever an account arrives.
///
/// Allowed by default, so a class built without an [Auth] behind it (tests,
/// tools) keeps its remote leg.
class RemoteAccess {
  bool allowed;

  new({this.allowed = true});

  static RemoteAccess of(BuildContext context) {
    return Provider.of<RemoteAccess>(context, listen: false);
  }
}
