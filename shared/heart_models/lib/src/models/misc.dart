import 'dart:async';

abstract interface class SignOutStateSentry {
  FutureOr<void> onSignOut();
}

abstract interface class Searchable {
  bool contains(String query);
}

abstract interface class Model {
  Map<String, dynamic> toMap();
}
