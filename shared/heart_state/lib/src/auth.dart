import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:heart_models/heart_models.dart';

class Auth with ChangeNotifier implements SignOutStateSentry {
  final _googleSignIn = GoogleSignIn(scopes: ['profile', 'email']);
  final _firebase = fb.FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final void Function(User?)? onUserChange;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  User? _user;

  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  set isInitialized(bool value) {
    _isInitialized = value;
    notifyListeners();
  }

  Auth({this.onUserChange, this.onError}) {
    _firebase.userChanges().listen(
      (user) {
        _user = _cast(user);
        onUserChange?.call(_user);
        _registerUser(_user);
      },
      onError: (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      },
    );
  }

  static Auth of(BuildContext context) {
    return Provider.of<Auth>(context, listen: false);
  }

  static Auth watch(BuildContext context) {
    return Provider.of<Auth>(context, listen: true);
  }

  Future<void> loginWithGoogle() async {
    try {
      var googleAccount = await _googleSignIn.signIn();
      final auth = await googleAccount?.authentication;
      if (auth case GoogleSignInAuthentication(:String? accessToken, :String? idToken)) {
        final cred = fb.GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );
        final authResult = await _firebase.signInWithCredential(cred);
        final user = authResult.user;

        _user = _cast(user);

        _registerUser(_user);

        notifyListeners();
      }
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  Future<void> _logout() async {
    await _googleSignIn.signOut();
    await _firebase.signOut();
  }

  static User? _cast(fb.User? user) {
    if (user == null) return null;
    return User(
      email: user.email,
      id: user.uid,
      displayName: user.displayName,
      avatar: user.photoURL,
      createdAt: user.metadata.creationTime,
    );
  }

  @override
  FutureOr<void> onSignOut() {
    return _logout();
  }

  Future<void> _registerUser(User? user) async {
    try {
      if (user == null) return;
      return _db //
          .collection("users")
          .doc(user.id)
          .set(user.toMap());
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }
}
