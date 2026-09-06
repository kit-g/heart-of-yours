import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'password.dart';
import 'remote.dart';

class Auth with ChangeNotifier implements SignOutStateSentry {
  final GoogleSignIn _googleSignIn;
  final fb.FirebaseAuth _firebase;
  final void Function(User?)? onUserChange;
  final AccountService _service;

  /// Called with the session token and uid once a user is in. The token is
  /// null for an anonymous session: nothing of it may reach the server.
  final Future<void> Function(String?, String?)? onEnter;

  /// Wipes everything the device store holds under a uid — what
  /// [eraseSession] calls before signing the anonymous session out. Null
  /// where there is nothing local to wipe.
  final Future<void> Function(String userId)? onErase;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final bool isWeb;
  final String? appleServiceId;
  final String? appleSignInRedirect;

  /// The remote leg's gate, shared with every state class. This is where it is
  /// decided — see [_adopt].
  final RemoteAccess remote;

  User? _user;

  User? get user => _user;

  /// True for an anonymous session too: the rest of the app keys everything on
  /// a uid and an anonymous one is a uid like any other.
  bool get isLoggedIn => _user != null;

  bool _isAnonymous = false;

  /// Whether the session is Firebase's anonymous kind — a uid with no account
  /// behind it. What an account adds (sync, socials, a coach) is off, and so is
  /// the remote leg, see [RemoteAccess].
  bool get isAnonymous => _isAnonymous;

  bool _sessionUnavailable = false;

  /// There is no user and the device could not mint an anonymous one — a
  /// first launch offline, or a Firebase project without the anonymous
  /// provider enabled. The router falls back to the sign-in gate on this: a
  /// login page beats a spinner nobody can dismiss. Cleared the moment any
  /// user arrives (see [ensureSession], retried on resume).
  bool get sessionUnavailable => _sessionUnavailable;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  set isInitialized(bool value) {
    _isInitialized = value;
    notifyListeners();
  }

  new({
    required this._service,
    this.onUserChange,
    this.onError,
    this.onEnter,
    this.onErase,
    this.isWeb = false,
    this.appleServiceId,
    this.appleSignInRedirect,
    fb.FirebaseAuth? firebase,
    GoogleSignIn? googleSignIn,
    RemoteAccess? remote,
  }) : _firebase = firebase ?? fb.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       remote = remote ?? RemoteAccess() {
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
    }

    _users = _firebase.userChanges().listen(
      (user) async {
        _adopt(user);
        onUserChange?.call(_user);
        notifyListeners();
        switch (user) {
          case fb.User(isAnonymous: true, :final uid):
            // no token handed over — the anonymous leg never reaches the
            // server, and registering an account is what an account is for
            await onEnter?.call(null, uid);
          case fb.User user:
            await onEnter?.call(await user.getIdToken(), user.uid);
            if (_disposed) return;
            try {
              _user = await _registerUser(_user);
            } on AccountDeleted {
              _logout();
            }
          case null:
            await ensureSession();
            // the gate is decided on this answer (see the router), and the
            // router re-reads it on a user change — which this is: there is
            // still no user, and now that is settled rather than pending
            if (_sessionUnavailable) onUserChange?.call(null);
        }
        // app startup is awaited above and can outlive a torn-down tree (a
        // test's, mid-session); there is nobody left to tell
        if (_disposed) return;
        isInitialized = true;
      },
      onError: (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      },
    );
  }

  /// The Firebase subscription, held so [dispose] can end it.
  StreamSubscription<fb.User?>? _users;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _users?.cancel();
    super.dispose();
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

  /// Makes sure there is a uid to key the local store on.
  ///
  /// On mobile the app works without an account, so a missing Firebase user —
  /// first launch, a sign-out, an anonymous uid Firebase has purged — is
  /// replaced by an anonymous one on the spot, and [fb.FirebaseAuth.userChanges]
  /// delivers it like any sign-in. A purged uid means a fresh, empty store;
  /// rows under the old one are keyed away from it and simply never read.
  ///
  /// The web keeps its sign-in gate (see the router), so there this is a no-op.
  /// Minting an anonymous user needs the network: a first launch offline
  /// reports the failure and is retried when the app next resumes.
  ///
  /// One attempt at a time: a sign-out is reported on more than one Firebase
  /// stream event, and a second anonymous sign-in racing the first is refused
  /// by the SDK (`admin-restricted-operation`) — which would read as the
  /// session being unavailable when it is a moment from arriving.
  Future<void> ensureSession() {
    if (isWeb || _firebase.currentUser != null) return Future.value();
    return _minting ??= _mintAnonymous().whenComplete(() => _minting = null);
  }

  Future<void>? _minting;

  Future<void> _mintAnonymous() async {
    try {
      await _firebase.signInAnonymously();
    } catch (error, stacktrace) {
      _sessionUnavailable = true;
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Takes [user] as the session: the model the app reads, whether it is an
  /// anonymous one, and — the consequence — whether the remote leg is open.
  void _adopt(fb.User? user) {
    _user = _cast(user);
    _isAnonymous = user?.isAnonymous ?? false;
    remote.allowed = user != null && !_isAnonymous;
    if (user != null) _sessionUnavailable = false;
  }

  Future<void> _loginWithGoogle(GoogleSignInAccount user) async {
    if (user.authentication case GoogleSignInAuthentication(:String? idToken)) {
      final cred = fb.GoogleAuthProvider.credential(idToken: idToken);
      return _loginWithCredential(cred);
    }
  }

  Future<PasswordValidationStatus> validatePassword(String password) {
    return _firebase.validatePassword(_firebase, password);
  }

  Future<void> loginWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final account = await _googleSignIn.authenticate(scopeHint: ['profile', 'email']);
      if (account.authentication case GoogleSignInAuthentication(:String? idToken)) {
        final cred = fb.GoogleAuthProvider.credential(idToken: idToken);
        return await _loginWithCredential(cred);
      }
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  Future<void> loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [.email, .fullName],
        webAuthenticationOptions: switch ((appleServiceId, appleSignInRedirect)) {
          (String clientId, String redirect) => WebAuthenticationOptions(
            clientId: clientId,
            redirectUri: Uri.parse(redirect),
          ),
          _ => null,
        },
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

      return await _loginWithCredential(
        appleToken,
        appleEmail: credential.email,
        appleName: name,
      );
    } on SignInWithAppleCredentialsException catch (e) {
      if (e.message.contains('popup_closed_by_user')) {
        return;
      }
    } catch (e, s) {
      return onError?.call(e, stacktrace: s);
    }
  }

  Future<void> _loginWithCredential(fb.OAuthCredential credential, {String? appleName, String? appleEmail}) {
    return _firebase.signInWithCredential(credential).then<void>(
      (result) {
        _adopt(result.user);
        _user = _user?.copyWith(displayName: appleName, email: appleEmail);

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
        // the stream usually got here first; adopting again is harmless and
        // makes sure an anonymous session does not read as one past this point
        _adopt(cred?.user);
        onEnter?.call(await cred?.user?.getIdToken(), cred?.user?.uid);
        _user = await _registerUser(_user);
      },
    );
  }

  Future<void> signUpWithEmailAndPassword({required String email, required String password, String? name}) async {
    final status = await validatePassword(password);
    if (!status.isValid) {
      throw PasswordRequirementsNotMet(status: status);
    }

    final cred = await _toFirebase<fb.UserCredential>(
      _firebase.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );

    if (name case String name) {
      if (cred?.user case fb.User user) {
        await user.updateDisplayName(name);
        _adopt(user);

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
    try {
      if (user == null || _isAnonymous) return user;
      if (!_service.isAuthenticated) return user;
      return await _service.registerAccount(user);
    } on UpgradeRequired catch (e) {
      onError?.call(e);
      return null;
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
          try {
            await _service.deleteAccount(accountId: accountId);
            await _logout();
          } on UpgradeRequired catch (e) {
            onError?.call(e);
          }
      }
    }

    return _toFirebase(callback());
  }

  /// "Erase my data", the anonymous session's counterpart to account deletion.
  ///
  /// There is no account to delete and nothing on a server, so what the user
  /// holds is the device store under their uid — [onErase] wipes it — and the
  /// session itself, which is signed out. On mobile a missing user is replaced
  /// by a fresh anonymous one at once (see [ensureSession]), so the app comes
  /// back under a new uid with nothing keyed to it: a first launch, minus the
  /// onboarding, whose flag is the device's and not touched here.
  ///
  /// The in-memory state is the caller's to clear — see `eraseState`, which
  /// pairs this with the same fan-out a sign-out gets. Refused for a session
  /// with an account behind it: that one deletes its account instead, and
  /// its local mirror is a copy of what the server keeps.
  Future<void> eraseSession() async {
    if (!_isAnonymous) return;
    if (_user?.id case String uid) {
      await onErase?.call(uid);
      // Firebase alone, not [_logout]: an anonymous session was never signed
      // into Google, and there is nothing to gain from initialising that
      // plugin only to sign out of it.
      await _firebase.signOut();
    }
  }

  Future<void> deleteAccountDeletionSchedule() async {
    switch (_user) {
      case User(id: String()):
        await _service.undoAccountDeletion();
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
    void Function(int bytes, int totalBytes)? onProgress,
    void Function(String url)? onDone,
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
          final success = await _service.uploadFile(uploadLink, avatar, onProgress: onProgress);
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

  factory fromCode(String code) {
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

  new(this.reason);

  @override
  String toString() {
    return reason.toString();
  }
}
