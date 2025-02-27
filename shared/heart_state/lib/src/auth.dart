import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
      (user) async {
        _user = _cast(user);
        onUserChange?.call(_user);
        _user = await _registerUser(_user);
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
        return _loginWithCredential(cred);
      }
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  Future<void> loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuth = fb.OAuthProvider('apple.com');
      final appleToken = oAuth.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final name = switch ((credential.givenName, credential.familyName)) {
        (String first, String last) when first.isNotEmpty && last.isNotEmpty => '$first $last',
        (String first, _) when first.isNotEmpty => first,
        (_, String last) when last.isNotEmpty => last,
        _ => null,
      };

      return _loginWithCredential(
        appleToken,
        appleEmail: credential.email,
        appleName: name,
      );
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  Future<void> _loginWithCredential(fb.OAuthCredential credential, {String? appleName, String? appleEmail}) async {
    return _firebase.signInWithCredential(credential).then<void>(
      (result) {
        _user = _cast(result.user)?.copyWith(displayName: appleName, email: appleEmail);

        return _registerUser(_user).then(
          (user) {
            _user = user;
            notifyListeners();
          },
        );
      },
    );
  }

  Future<void> loginWithEmailAndPassword({required String email, required String password}) async {
    return _toFirebase(
      _firebase.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> sendPasswordRecoveryEmail(String email) async {
    return _toFirebase(
      _firebase.sendPasswordResetEmail(email: email),
    );
  }

  Future<T?> _toFirebase<T>(Future<T?> action) async {
    try {
      return await action;
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(AuthExceptionReason.fromCode(error.code));
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return Future.error(error);
    }
  }

  static Future<bool> isAppleSignInAvailable() {
    return SignInWithApple.isAvailable();
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

  static User? fromJson(Map? json) {
    return switch (json) {
      {'id': String id} => User(
          id: id,
          email: json['email'],
          displayName: json['displayName'],
          avatar: json['avatar'],
          createdAt: (json['createdAt'] as Timestamp).toDate(),
        ),
      _ => null,
    };
  }

  @override
  FutureOr<void> onSignOut() {
    return _logout();
  }

  Future<User?> _registerUser(User? user) async {
    if (user == null) return user;
    try {
      final doc = _db.collection('users').doc(user.id);
      final snapshot = await doc.get();

      if (!snapshot.exists) {
        final userDoc = {
          ...user.toMap(),
          'lastLogin': FieldValue.serverTimestamp(),
        };

        await doc.set(userDoc);
        return user;
      } else {
        await doc.update({'lastLogin': FieldValue.serverTimestamp()});
        return fromJson(snapshot.data());
      }
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return user;
    }
  }
}

enum AuthExceptionReason {
  invalidEmail,
  wrongPassword,
  userDisabled,
  userNotFound,
  unknown;

  factory AuthExceptionReason.fromCode(String code) {
    return switch (code) {
      'wrong-password' => wrongPassword,
      'invalid-credential' => wrongPassword,
      'invalid-email' => invalidEmail,
      'user-disabled' => userDisabled,
      'user-not-found' => userNotFound,
      _ => unknown,
    };
  }
}

class AuthException implements Exception {
  final AuthExceptionReason reason;

  AuthException(this.reason);

  @override
  String toString() {
    return reason.toString();
  }
}
