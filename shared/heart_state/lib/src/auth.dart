import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class Auth with ChangeNotifier implements SignOutStateSentry {
  final GoogleSignIn _googleSignIn;
  final fb.FirebaseAuth _firebase;
  final void Function(User?)? onUserChange;
  final AccountService _service;
  final Future<void> Function(String?, String?)? onEnter;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final bool isWeb;

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
    required this.isWeb,
    required AccountService service,
    fb.FirebaseAuth? firebase,
    GoogleSignIn? googleSignIn,
  })  : _service = service,
        _firebase = firebase ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['profile', 'email']) {
    // such is the way with Google sign-in
    // on the web - Firebase does not pick it up
    if (isWeb) {
      _googleSignIn.authenticationEvents.listen(
        (event) async {
          switch (event) {
            case GoogleSignInAuthenticationEventSignIn(user: GoogleSignInAccount account):
              await _loginWithGoogle(account);
              await onEnter?.call(account.authentication.idToken, user?.id);
            case GoogleSignInAuthenticationEventSignOut():
              _user = null;
              notifyListeners();
          }
        },
      );
    } else {
      _firebase.userChanges().listen(
        (user) async {
          _user = _cast(user);
          onUserChange?.call(_user);
          notifyListeners();
          if (user case fb.User user) {
            await onEnter?.call(await user.getIdToken(), user.uid);
            try {
              _user = await _registerUser(_user);
            } on AccountDeleted {
              _logout();
            }
          }

          isInitialized = true;
        },
        onError: (error, stacktrace) {
          onError?.call(error, stacktrace: stacktrace);
        },
      );
    }
  }

  static Auth of(BuildContext context) {
    return Provider.of<Auth>(context, listen: false);
  }

  static Auth watch(BuildContext context) {
    return Provider.of<Auth>(context, listen: true);
  }

  Future<void> initGoogleSignIn() {
    return _googleSignIn.initialize();
  }

  Future<void> _loginWithGoogle(GoogleSignInAccount user) async {
    if (user.authentication case GoogleSignInAuthentication(:String? idToken)) {
      final cred = fb.GoogleAuthProvider.credential(idToken: idToken);
      return _loginWithCredential(cred);
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final account = await _googleSignIn.authenticate(scopeHint: ['profile', 'email']);
      if (account.authentication case GoogleSignInAuthentication(:String? idToken)) {
        final cred = fb.GoogleAuthProvider.credential(idToken: idToken);
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
    return _toFirebase<fb.UserCredential>(
      _firebase.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).then(
      (cred) async {
        onEnter?.call(await cred?.user?.getIdToken(), cred?.user?.uid);
        _user = await _registerUser(_user);
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

    return onEnter?.call(await cred?.user?.getIdToken(), cred?.user?.uid);
  }

  Future<void> updateName(String? name) async {
    _firebase.currentUser?.updateDisplayName(name);
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
    await _googleSignIn.initialize();
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

  Future<User?> _registerUser(User? user) async {
    if (user == null) return user;
    if (!_service.isAuthenticated) return user;
    return _service.registerAccount(user);
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

  Future<({String url, Map<String, String> fields})?> getAvatarUploadLink({String? imageMimeType}) async {
    if (user?.id case String userId) {
      return _service.getAvatarUploadLink(userId, imageMimeType: imageMimeType);
    }
    return null;
  }

  Future<bool> updateAvatar(
    (Uint8List, {String? mimeType, String? name}) localImage,
    String avatarStorage, {
    final void Function(int bytes, int totalBytes)? onProgress,
    final void Function(String url)? onDone,
  }) async {
    if (user case User user) {
      // update local image and notify the UI
      user.localAvatar = localImage.$1;
      notifyListeners();
      try {
        // get pre-signed URL for the upload
        final uploadLink = await _service.getAvatarUploadLink(user.id, imageMimeType: localImage.mimeType);
        if (uploadLink != null) {
          // push the image to the bucket
          final avatar = ('file', localImage.$1, contentType: localImage.mimeType, filename: localImage.name);
          final success = await _service.uploadAvatar(uploadLink, avatar, onProgress: onProgress);
          if (success) {
            // if it succeeds, store the URL in the database
            // and notify Firebase about it
            await Future.delayed(const Duration(seconds: 5));
            final resultingUrl = '$avatarStorage/${user.id}?v=${DateTime.now().millisecondsSinceEpoch}';
            _firebase.currentUser?.updatePhotoURL(resultingUrl);
            onDone?.call(resultingUrl);
          }
          return success;
        }
      } catch (e, s) {
        onError?.call(e, stacktrace: s);
        return false;
      }
    }
    return false;
  }

  Future<bool> removeAvatar() async {
    user
      ?..localAvatar = null
      ..remoteAvatar = null;
    _firebase.currentUser?.updateProfile(photoURL: null);

    if (user?.id case String userId) {
      _service.removeAvatar(userId);
    }

    notifyListeners();
    return true;
  }
}

enum AuthExceptionReason {
  invalidEmail,
  wrongPassword,
  userDisabled,
  userNotFound,
  emailInUse,
  weakPassword,
  networkRequestFailed,
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
      'network-request-failed' => networkRequestFailed,
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
