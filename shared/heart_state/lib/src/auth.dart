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
  final AccountService _service;
  final Future<void> Function()? onEnter;
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

  Auth({
    this.onUserChange,
    this.onError,
    this.onEnter,
    required AccountService service,
  }) : _service = service {
    _firebase.userChanges().listen(
      (user) async {
        _user = _cast(user);
        _user = await _registerUser(_user);
        onUserChange?.call(_user);
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
      return onError?.call(e, stacktrace: s);
    }
  }

  Future<void> _loginWithCredential(fb.OAuthCredential credential, {String? appleName, String? appleEmail}) {
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

  Future<void> logInWithEmailAndPassword({required String email, required String password}) {
    return _toFirebase<void>(
      _firebase.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).then(
      (_) {
        return onEnter?.call();
      },
    );
  }

  Future<void> signUpWithEmailAndPassword({required String email, required String password, String? name}) async {
    final cred = await _toFirebase<fb.UserCredential>(
      _firebase.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );

    if (name case String name) {
      if (cred?.user case fb.User user) {
        await user.updateDisplayName(name);
        _user = _cast(user);

        updateName(name);
        notifyListeners();
      }
    }

    if (!(cred?.user?.emailVerified ?? false)) {
      cred?.user?.sendEmailVerification();
    }

    return onEnter?.call();
  }

  Future<void> updateName(String? name) async {
    if (user?.id case String userId) {
      _firebase.currentUser?.updateDisplayName(name);
      final doc = _db.collection('users').doc(userId);

      final snapshot = await doc.get();

      if (snapshot.exists) {
        await doc.update({'displayName': name});
      }
    }
  }

  Future<void> sendPasswordRecoveryEmail(String email) {
    return _toFirebase<void>(
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
          scheduledForDeletionAt: switch (json['scheduledForDeletionAt']) {
            String s when s.isNotEmpty => DateTime.tryParse(s),
            _ => null,
          },
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

      if (snapshot.exists) {
        await doc.update({'lastLogin': FieldValue.serverTimestamp()});
        return fromJson(snapshot.data());
      } else {
        final userDoc = {
          ...user.toMap(),
          'lastLogin': FieldValue.serverTimestamp(),
        };

        await doc.set(userDoc);
        return user;
      }
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return user;
    }
  }

  Future<String?>? get sessionToken => _firebase.currentUser?.getIdToken();

  Future<void> scheduleAccountForDeletion({
    required String password,
    required void Function(String?) onAuthenticate,
  }) async {
    Future<void> callback() async {
      switch (_user) {
        case User(:String email, id: String accountId):
          final cred = fb.EmailAuthProvider.credential(email: email, password: password);
          final authenticated = await _firebase.currentUser?.reauthenticateWithCredential(cred);
          onAuthenticate(await authenticated?.user?.getIdToken());
          await _service.deleteAccount(accountId: accountId);
          await _logout();
      }
    }

    return _toFirebase(callback());
  }

  Future<void> deleteAccountDeletionSchedule() async {
    switch (_user) {
      case User(id: String accountId):
        await _service.undoAccountDeletion(accountId);
        // copy without the deletion timestamp
        _user = _user?.copyWith();
        notifyListeners();
    }
  }
}

enum AuthExceptionReason {
  invalidEmail,
  wrongPassword,
  userDisabled,
  userNotFound,
  emailInUse,
  weakPassword,
  unknown;

  factory AuthExceptionReason.fromCode(String code) {
    return switch (code) {
      'wrong-password' => wrongPassword,
      'invalid-credential' => wrongPassword,
      'invalid-email' => invalidEmail,
      'user-disabled' => userDisabled,
      'user-not-found' => userNotFound,
      'email-already-in-use' => emailInUse,
      'weak-password' => weakPassword,
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
