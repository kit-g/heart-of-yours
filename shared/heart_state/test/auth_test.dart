import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    show InternalUserInfo, PasswordPolicy;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heart_models/heart_models.dart' show User;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

/// A Firebase project with the anonymous provider switched off answers every
/// anonymous sign-in with `admin-restricted-operation`.
class _NoAnonymousSignIn extends MockFirebaseAuth {
  new() : super(signedIn: false);

  @override
  Future<fb.UserCredential> signInAnonymously() {
    throw fb.FirebaseAuthException(code: 'admin-restricted-operation');
  }
}

/// An anonymous Firebase user that can be linked, the way the SDK links: the
/// credential is new to the project, so the same uid comes back with an
/// account behind it and the user stream says so. The package's own mock
/// hands the anonymous user straight back.
// ignore: must_be_immutable — MockUser's own fields are mutable; nothing here adds one
class _LinkableAnonymous extends MockUser {
  final MockFirebaseAuth auth;

  new(this.auth) : super(isAnonymous: true, uid: 'anon-1');

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) {
    // the mock's sign-in is the one way to make it adopt a user and say so on
    // its stream; the user it adopts is this uid with an account behind it
    auth.mockUser = MockUser(uid: uid, email: 'linked@test', displayName: 'Linked');
    return auth.signInWithCredential(credential);
  }
}

/// An anonymous user whose credential already has an account: linking is
/// refused, and a sign-in with the same credential lands on that account.
///
/// [code] is which refusal: the credential itself is taken, or only its email
/// is, by an account under another provider.
// ignore: must_be_immutable — see _LinkableAnonymous
class _TakenCredential extends MockUser {
  final MockFirebaseAuth auth;
  final String code;

  new(this.auth, {this.code = 'credential-already-in-use'}) : super(isAnonymous: true, uid: 'anon-1');

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) async {
    auth.mockUser = MockUser(uid: 'acct-1', email: 'acct@test');
    throw fb.FirebaseAuthException(code: code);
  }
}

/// The same refusal as [_TakenCredential], but carrying the replacement
/// credential the way Firebase does with `credential-already-in-use`, which
/// the sign-in after the refusal prefers. Apple no longer comes this way: its
/// token goes straight to a sign-in (see [_AppleFirebase]).
// ignore: must_be_immutable — see _LinkableAnonymous
class _TakenCredentialWithFresh extends MockUser {
  final MockFirebaseAuth auth;

  static final fresh = fb.OAuthProvider('apple.com').credential(idToken: 'fresh-token');

  new(this.auth) : super(isAnonymous: true, uid: 'anon-1');

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) async {
    auth.mockUser = MockUser(uid: 'acct-1', email: 'acct@test');
    throw fb.FirebaseAuthException(code: 'credential-already-in-use', credential: fresh);
  }
}

/// Apple's sheet, as a test can stand in for it: every showing hands out a
/// new identity token, numbered, so a test can tell the first from the
/// second — which is the whole question when a link spends the first.
class _AppleSheet {
  var shown = 0;

  Future<AuthorizationCredentialAppleID> call({
    required List<AppleIDAuthorizationScopes> scopes,
    WebAuthenticationOptions? webAuthenticationOptions,
  }) async {
    shown++;
    return AuthorizationCredentialAppleID(
      userIdentifier: 'apple-user',
      givenName: null,
      familyName: null,
      authorizationCode: 'code-$shown',
      email: null,
      identityToken: 'apple-token-$shown',
      state: null,
    );
  }
}

/// A Firebase that refuses every provider sign-in the way it does when the
/// email already belongs to an account under another provider.
class _RefusingFirebase extends _Firebase {
  @override
  Future<fb.UserCredential> signInWithCredential(fb.AuthCredential? credential) {
    if (credential != null) redeemed.add(credential);
    throw fb.FirebaseAuthException(code: 'account-exists-with-different-credential');
  }
}

/// A signed-in account that records what gets linked onto it and grows its
/// provider list the way Firebase's would.
// ignore: must_be_immutable — see _LinkableAnonymous
class _Account extends MockUser {
  final linked = <fb.AuthCredential>[];

  /// Thrown by the next link, as Firebase would refuse it.
  fb.FirebaseAuthException? refusal;

  // a plain parameter, not `super.email`: the initializer list cannot read a
  // super parameter, and the getter it falls back to is nullable
  new({required String uid, required String email, List<String> providers = const ['google.com']})
    : super(
        uid: uid,
        email: email,
        isAnonymous: false,
        providerData: [
          for (final id in providers)
            fb.UserInfo.fromPigeon(
              InternalUserInfo(providerId: id, uid: uid, email: email, isAnonymous: false, isEmailVerified: true),
            ),
        ],
      );

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) async {
    if (refusal case final refusal?) throw refusal;
    linked.add(credential);
    providerData.add(
      fb.UserInfo.fromPigeon(
        InternalUserInfo(
          providerId: credential.providerId,
          uid: uid,
          email: email,
          isAnonymous: false,
          isEmailVerified: true,
        ),
      ),
    );
    return super.linkWithCredential(credential);
  }
}

/// A Firebase whose provider sign-in is refused because the address belongs
/// to an account under another sign-in, and whose password sign-in then
/// lands on that account.
class _OtherProviderFirebase extends _Firebase {
  late final _Account owner;

  @override
  Future<fb.UserCredential> signInWithCredential(fb.AuthCredential? credential) {
    if (credential != null) redeemed.add(credential);
    throw fb.FirebaseAuthException(code: 'account-exists-with-different-credential', email: 'acct@test');
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({required String email, required String password}) {
    owner = _Account(uid: 'acct-1', email: email, providers: const ['password']);
    mockUser = owner;
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

/// An anonymous session that must never be linked: Apple's token goes
/// straight to a sign-in, and a link would spend it.
// ignore: must_be_immutable — see _LinkableAnonymous
class _NeverLinked extends MockUser {
  new() : super(isAnonymous: true, uid: 'anon-1');

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) {
    fail('an Apple token was spent on a link');
  }
}

/// A Firebase whose provider sign-in lands on an Apple account: an existing
/// one, or one the sign-in just created.
class _AppleFirebase extends _Firebase {
  final bool newAccount;

  new({this.newAccount = false});

  @override
  Future<fb.UserCredential> signInWithCredential(fb.AuthCredential? credential) async {
    mockUser = MockUser(uid: newAccount ? 'apple-new' : 'acct-1', email: 'apple@test');
    return _Arrived(await super.signInWithCredential(credential), isNewUser: newAccount);
  }
}

/// A sign-in's result that says whether it created the account, as
/// Firebase's does and the mock's does not.
class _Arrived implements fb.UserCredential {
  final fb.UserCredential _inner;
  final bool isNewUser;

  new(this._inner, {required this.isNewUser});

  @override
  fb.User? get user => _inner.user;

  @override
  fb.AuthCredential? get credential => _inner.credential;

  @override
  fb.AdditionalUserInfo? get additionalUserInfo => fb.AdditionalUserInfo(isNewUser: isNewUser);
}

/// A user whose link attempt fails for any other reason — the SDK's own
/// refusal, a dropped network.
// ignore: must_be_immutable — see _LinkableAnonymous
class _UnlinkableAnonymous extends MockUser {
  new() : super(isAnonymous: true, uid: 'anon-1');

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) async {
    throw fb.FirebaseAuthException(code: 'network-request-failed');
  }
}

/// The mock Firebase, taught the two things the email paths need of it: a
/// password policy to validate against, and an account to sign into — the
/// package's own sign-in adopts whoever `mockUser` is, which for an anonymous
/// session is the session itself.
class _Firebase extends MockFirebaseAuth {
  new() : super(signedIn: false);

  /// Every credential a sign-in was asked to redeem, in order. Which one
  /// arrives here is the whole question when a link is refused.
  final redeemed = <fb.AuthCredential>[];

  @override
  Future<fb.UserCredential> signInWithCredential(fb.AuthCredential? credential) {
    if (credential != null) redeemed.add(credential);
    return super.signInWithCredential(credential);
  }

  @override
  Future<fb.PasswordValidationStatus> validatePassword(fb.FirebaseAuth auth, String? password) async {
    return fb.PasswordValidationStatus(true, PasswordPolicy(const {}));
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({required String email, required String password}) {
    mockUser = MockUser(uid: 'acct-1', email: email);
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

/// What the Google plugin hands back after its sheet: enough for
/// [Auth.loginWithGoogle] to build a Firebase credential from.
class _GoogleAccount extends Fake implements GoogleSignInAccount {
  @override
  GoogleSignInAuthentication get authentication => const GoogleSignInAuthentication(idToken: 'google-token');
}

void main() {
  late MockAccountService account;

  setUp(() {
    account = MockAccountService();
  });

  group('Provider helpers', () {
    testWidgets('of(context) returns the provided instance', (tester) async {
      final sut = Auth(service: account, firebase: MockFirebaseAuth());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final got = Auth.of(context);
              expect(identical(got, sut), isTrue);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('watch(context) rebuilds on notifyListeners', (tester) async {
      final sut = Auth(service: account, firebase: MockFirebaseAuth());
      int builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final _ = Auth.watch(context).isInitialized;
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builds, 1);

      sut.isInitialized = true; // triggers notify
      await tester.pump();
      expect(builds, 2);
    });
  });

  group('account deletion schedule', () {
    test('cancelling clears the deletion timestamp so the router stops sending the user back', () async {
      final firebase = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'acct-1', email: 'acct@test', displayName: 'Sam'),
      );
      when(account.isAuthenticated).thenReturn(true);
      // the profile the server returns is the one carrying the schedule
      when(account.registerAccount(any)).thenAnswer(
        (inv) async => User(
          id: (inv.positionalArguments.first as User).id,
          email: 'acct@test',
          displayName: 'Sam',
          scheduledForDeletionAt: DateTime.utc(2026, 10, 19),
        ),
      );
      when(account.undoAccountDeletion()).thenAnswer((_) async => null);

      final sut = Auth(service: account, firebase: firebase);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        sut.user?.scheduledForDeletionAt,
        isNotNull,
        reason: 'the account came back scheduled; the goodbye page is shown off this',
      );

      await sut.deleteAccountDeletionSchedule();

      // The regression this guards: `copyWith()` used to null the timestamp
      // because it was a parameter there. It is now carried over from `this`,
      // so a copy keeps the schedule, the router keeps redirecting, and undo
      // looks broken while the server has already cancelled it.
      expect(sut.user?.scheduledForDeletionAt, isNull);
      expect(sut.user?.id, 'acct-1', reason: 'everything else survives the rebuild');
      expect(sut.user?.email, 'acct@test');
      expect(sut.user?.displayName, 'Sam');
      verify(account.undoAccountDeletion()).called(1);
    });
  });

  group('lifecycle/init', () {
    test('subscribes to userChanges, sets user and notifies, then sets initialized and notifies again', () async {
      final firebase = MockFirebaseAuth();

      // record onEnter args and ensure registerAccount is called when authenticated
      String? onEnterToken;
      String? onEnterUid;
      when(account.isAuthenticated).thenReturn(true);
      when(account.registerAccount(any)).thenAnswer((inv) async => inv.positionalArguments.first as User);

      int userChanges = 0;
      final sut = Auth(
        service: account,
        firebase: firebase,
        isWeb: false,
        onEnter: (t, u) async {
          onEnterToken = t;
          onEnterUid = u;
        },
        onUserChange: (_) => userChanges++,
      );

      // Trigger a sign-in event so userChanges emits
      await firebase.signInWithCredential(
        fb.GoogleAuthProvider.credential(idToken: 'token', accessToken: 'access'),
      );

      final probe = ListenerProbe()..attach(sut);

      // Allow the auth stream microtasks to deliver
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.user, isNotNull);
      expect(sut.user!.id, isNotEmpty);
      expect(sut.isInitialized, isTrue);
      // Depending on scheduling, the first notify may happen before we attach the probe.
      // We only assert at least one notification occurred during initialization.
      expect(probe.notifications, greaterThanOrEqualTo(1));
      expect(userChanges, greaterThanOrEqualTo(1));

      // onEnter should receive token and uid
      expect(onEnterUid, isNotEmpty);
      expect(onEnterToken, isNotNull);
      verify(account.registerAccount(any)).called(1);
    });
  });

  group('Sign in with Apple', () {
    /// What Apple's sheet hands back. The name comes on the first
    /// authorization only; every later one has none.
    void appleAnswers({String? givenName, String? familyName}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SignInWithApple.channel,
        (call) async => {
          'type': 'appleid',
          'authorizationCode': 'code',
          'identityToken': 'apple-token',
          'givenName': givenName,
          'familyName': familyName,
          'email': 'muffin@heart.test',
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SignInWithApple.channel,
          null,
        ),
      );
    }

    testWidgets('the name Apple says once is kept on the account, so no later read registers it nameless', (
      tester,
    ) async {
      appleAnswers(givenName: 'Muffin', familyName: 'Cat');
      final firebase = MockFirebaseAuth(
        signedIn: false,
        mockUser: MockUser(uid: 'apple-1', email: 'muffin@heart.test'),
      );
      final registered = <String?>[];
      when(account.isAuthenticated).thenReturn(true);
      when(account.registerAccount(any)).thenAnswer((inv) async {
        final user = inv.positionalArguments.first as User;
        registered.add(user.displayName);
        // the server keeps the name it is sent, null included
        return user;
      });
      final sut = Auth(service: account, firebase: firebase, isWeb: false);

      await tester.runAsync(() async {
        await sut.loginWithApple();
        // the user stream's own registration, behind the sign-in's
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(firebase.currentUser?.displayName, 'Muffin Cat');
      expect(sut.user?.displayName, 'Muffin Cat');
      expect(registered, isNotEmpty);
      expect(registered, everyElement('Muffin Cat'));
      sut.dispose();
    });

    testWidgets('a later sign-in, which Apple sends without a name, keeps the one on the account', (tester) async {
      appleAnswers();
      final firebase = MockFirebaseAuth(
        signedIn: false,
        mockUser: MockUser(uid: 'apple-1', email: 'muffin@heart.test', displayName: 'Muffin Cat'),
      );
      when(account.isAuthenticated).thenReturn(true);
      when(account.registerAccount(any)).thenAnswer((inv) async => inv.positionalArguments.first as User);
      final sut = Auth(service: account, firebase: firebase, isWeb: false);

      await tester.runAsync(() async {
        await sut.loginWithApple();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(firebase.currentUser?.displayName, 'Muffin Cat');
      expect(sut.user?.displayName, 'Muffin Cat');
      sut.dispose();
    });
  });

  group('methods and boundaries', () {
    test('getAvatarUploadLink returns null when user is null, does not call service', () async {
      final sut = Auth(service: account, firebase: MockFirebaseAuth());
      final res = await sut.getAvatarUploadLink();
      expect(res, isNull);
      verifyZeroInteractions(account);
    });

    test('getAvatarUploadLink delegates to service when user present', () async {
      final firebase = MockFirebaseAuth();
      final sut = Auth(service: account, firebase: firebase);

      // sign in a user so sut has a user id
      await firebase.signInWithCredential(
        fb.GoogleAuthProvider.credential(idToken: 'token', accessToken: 'access'),
      );

      when(
        account.getAvatarUploadLink(any, imageMimeType: anyNamed('imageMimeType')),
      ).thenAnswer((_) async => (url: 'https://u', fields: <String, String>{}));

      // wait for sut.user to update
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final expectedId = sut.user!.id;
      final res = await sut.getAvatarUploadLink(imageMimeType: 'image/png');
      expect(res, isNotNull);
      verify(account.getAvatarUploadLink(expectedId, imageMimeType: 'image/png')).called(1);
    });

    test(
      'updateAvatar: when user present but no upload link, sets local avatar, notifies once and returns false',
      () async {
        final firebase = MockFirebaseAuth();
        final sut = Auth(service: account, firebase: firebase, googleSignIn: MockGoogleSignIn());

        // sign in and wait for delivery before attaching probe
        await firebase.signInWithCredential(
          fb.GoogleAuthProvider.credential(idToken: 'token', accessToken: 'access'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final probe = ListenerProbe()..attach(sut);

        when(account.getAvatarUploadLink(any, imageMimeType: anyNamed('imageMimeType'))).thenAnswer((_) async => null);

        final bytes = Uint8List.fromList([1, 2, 3]);
        final ok = await sut.updateAvatar((bytes, mimeType: 'image/png', name: 'a.png'), 's3://avatars');

        expect(ok, isFalse);
        expect(probe.notifications, 1); // local avatar set triggers one notify
        verify(account.getAvatarUploadLink(any, imageMimeType: 'image/png')).called(1);
        verifyNever(account.uploadFile(any, any, onProgress: anyNamed('onProgress')));
      },
    );

    test('deleteAccountDeletionSchedule: no-op when user is null (no service calls)', () async {
      final firebase = MockFirebaseAuth();
      final sut = Auth(service: account, firebase: firebase);
      await sut.deleteAccountDeletionSchedule();

      verifyZeroInteractions(account);
    });
  });

  group('anonymous session', () {
    test('a missing user is replaced by an anonymous one, with the remote leg closed', () async {
      final firebase = MockFirebaseAuth(signedIn: false);
      final remote = RemoteAccess();
      String? token;
      String? uid;
      var entered = 0;
      when(account.isAuthenticated).thenReturn(true);

      final sut = Auth(
        service: account,
        firebase: firebase,
        remote: remote,
        googleSignIn: MockGoogleSignIn(),
        onEnter: (t, u) async {
          token = t;
          uid = u;
          entered++;
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.isLoggedIn, isTrue, reason: 'an anonymous uid is a uid like any other');
      expect(sut.isAnonymous, isTrue);
      expect(sut.isInitialized, isTrue);
      expect(remote.allowed, isFalse);
      expect(entered, 1);
      expect(uid, sut.user!.id);
      expect(token, isNull, reason: 'no anonymous token may reach the server');
      verifyNever(account.registerAccount(any));
    });

    test('the web keeps its gate: no user, no anonymous sign-in', () async {
      final firebase = MockFirebaseAuth(signedIn: false);
      final remote = RemoteAccess();

      final sut = Auth(
        service: account,
        firebase: firebase,
        remote: remote,
        isWeb: true,
        googleSignIn: MockGoogleSignIn(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.isLoggedIn, isFalse);
      expect(sut.isAnonymous, isFalse);
      expect(sut.isInitialized, isTrue);
      expect(remote.allowed, isFalse);
    });

    test('a refused anonymous sign-in leaves the session unavailable, and says so through onUserChange', () async {
      final firebase = _NoAnonymousSignIn();
      final remote = RemoteAccess();
      final errors = <Object>[];
      final changes = <User?>[];

      final sut = Auth(
        service: account,
        firebase: firebase,
        remote: remote,
        googleSignIn: MockGoogleSignIn(),
        onError: (error, {stacktrace}) => errors.add(error),
        onUserChange: changes.add,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.isLoggedIn, isFalse);
      expect(sut.sessionUnavailable, isTrue, reason: 'the router falls back to the gate on this');
      expect(sut.isInitialized, isTrue, reason: 'the login page shows its form, not its spinner');
      expect(remote.allowed, isFalse);
      expect(errors, hasLength(1));
      // once for the missing user, once more for the settled answer
      expect(changes, [null, null]);
    });

    test('ensureSession is a no-op while someone is signed in', () async {
      final firebase = MockFirebaseAuth(mockUser: MockUser(uid: 'u1'), signedIn: true);
      final sut = Auth(service: account, firebase: firebase, googleSignIn: MockGoogleSignIn());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sut.ensureSession();

      expect(sut.user?.id, 'u1');
      expect(sut.isAnonymous, isFalse);
    });

    test('an account signed into from an anonymous session opens the remote leg', () async {
      final firebase = MockFirebaseAuth(signedIn: false);
      final remote = RemoteAccess();
      when(account.isAuthenticated).thenReturn(true);
      when(account.registerAccount(any)).thenAnswer((inv) async => inv.positionalArguments.first as User);

      final sut = Auth(service: account, firebase: firebase, remote: remote, googleSignIn: MockGoogleSignIn());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sut.isAnonymous, isTrue);
      expect(remote.allowed, isFalse);

      await firebase.signInWithCredential(
        fb.GoogleAuthProvider.credential(idToken: 'token', accessToken: 'access'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.isAnonymous, isFalse);
      expect(remote.allowed, isTrue);
      verify(account.registerAccount(any)).called(1);
    });
  });

  group('an anonymous session signing in (heart-of-yours#96)', () {
    /// The order things happened in, as the app would see them.
    late List<String> events;
    late RemoteAccess remote;
    late MockGoogleSignIn google;
    late _Firebase firebase;
    late _AppleSheet apple;

    /// Fresh per [build], unlike the file-level mocks: these assertions are
    /// about what one run reported, and a shared one would carry the previous
    /// test's events in.
    late ReportedAnalytics reported;

    /// An [Auth] over a Firebase that has minted [anonymous] as the session,
    /// with the Google sheet answering an account whose credential the
    /// anonymous user decides the fate of.
    Future<Auth> build(
      MockUser Function(MockFirebaseAuth) anonymous, {
      void Function(Object)? onError,
      _Firebase Function()? firebaseOf,
    }) async {
      events = [];
      remote = RemoteAccess();
      google = MockGoogleSignIn();
      apple = _AppleSheet();
      when(google.initialize()).thenAnswer((_) async {});
      when(google.authenticate(scopeHint: anyNamed('scopeHint'))).thenAnswer((_) async => _GoogleAccount());
      when(account.isAuthenticated).thenReturn(true);
      when(account.registerAccount(any)).thenAnswer((inv) async => inv.positionalArguments.first as User);
      firebase = firebaseOf?.call() ?? _Firebase();
      firebase.mockUser = anonymous(firebase);
      reported = ReportedAnalytics();
      final sut = Auth(
        service: account,
        firebase: firebase,
        remote: remote,
        googleSignIn: google,
        appleCredentials: apple.call,
        analytics: Analytics(service: reported),
        onLink: (from, to) async => events.add('link $from→$to allowed=${remote.allowed}'),
        onUserChange: (user) => events.add('user ${user?.id}'),
        onEnter: (token, uid) async => events.add('enter $uid'),
        onError: (error, {stacktrace}) => onError?.call(error),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sut.isAnonymous, isTrue);
      expect(sut.user?.id, 'anon-1');
      events.clear();
      return sut;
    }

    test('link: the credential is new, the uid survives, the store is owed a replay', () async {
      final sut = await build(_LinkableAnonymous.new);

      await sut.loginWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.user?.id, 'anon-1', reason: 'the same uid, now with an account behind it');
      expect(sut.isAnonymous, isFalse);
      // the link is announced before the new user is keyed in anywhere, and
      // with the remote leg already held closed for the replay
      expect(events, ['link anon-1→anon-1 allowed=false', 'user anon-1', 'enter anon-1']);
      expect(remote.account, isTrue);
      expect(remote.replaying, isTrue, reason: 'the replay opens the leg when it is done');
      expect(remote.allowed, isFalse);
      // the profile is registered — the first authenticated call creates it —
      // and the sign-in path and the stream handler both make sure of that
      verify(account.registerAccount(any)).called(greaterThanOrEqualTo(1));
      expect(reported.arrivals, ['linked'], reason: 'the uid survived, so nothing had to be rekeyed');
    });

    test('existing account: linking is refused, the session signs in, the uid changes', () async {
      final sut = await build(_TakenCredential.new);

      await sut.loginWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.user?.id, 'acct-1');
      expect(sut.isAnonymous, isFalse);
      expect(events, ['link anon-1→acct-1 allowed=false', 'user acct-1', 'enter acct-1']);
      expect(remote.allowed, isFalse);
      // The dimension the whole funnel turns on, and the only place the two
      // paths can still be told apart: by the time anything downstream looks,
      // both are an account with a replay owed.
      expect(reported.arrivals, ['takeover']);
    });

    test('email taken by another provider: the session signs in to that account', () async {
      final errors = <Object>[];
      final sut = await build((auth) => _TakenCredential(auth, code: 'email-already-in-use'), onError: errors.add);

      await sut.loginWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(errors, isEmpty, reason: 'it was the whole Google sign-in failing');
      expect(sut.user?.id, 'acct-1');
      expect(sut.isAnonymous, isFalse);
      expect(events, ['link anon-1→acct-1 allowed=false', 'user acct-1', 'enter acct-1']);
      expect(reported.arrivals, ['takeover']);
    });

    test('backing out of the sheet is a sign-in that did not start, not one that failed', () async {
      final errors = <Object>[];
      final sut = await build(_LinkableAnonymous.new, onError: errors.add);
      when(
        google.authenticate(scopeHint: anyNamed('scopeHint')),
      ).thenThrow(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));

      await sut.loginWithGoogle();

      // Cancelling is the most common way any of these ends. Counted as a
      // failure it would be most of `signup_failed`, and the errors worth
      // finding would be a rounding error inside it.
      expect(reported.names, isNot(contains('signup_failed')));
      // The attempt itself still counts: started-and-abandoned is the drop
      // the funnel exists to show.
      expect(reported.names, contains('signup_started'));
      expect(reported.arrivals, isEmpty);
      // Nor is it an error: it was most of what Sentry heard from sign-in.
      expect(errors, isEmpty);
    });

    test('an existing Apple account signs in with the credential Firebase hands back, not the spent one', () async {
      final sut = await build(_TakenCredentialWithFresh.new);

      await sut.loginWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.user?.id, 'acct-1', reason: 'the handover still lands on the account');
      expect(sut.isAnonymous, isFalse);
      expect(
        firebase.redeemed.last,
        same(_TakenCredentialWithFresh.fresh),
        reason: 'the spent credential would come back as a duplicate nonce',
      );
    });

    test('Apple is one sheet: its token goes straight to a sign-in, never spent on a link', () async {
      // an Apple token is redeemed once; linking first spent it on every
      // returning user, and the sheet came twice
      final sut = await build((_) => _NeverLinked(), firebaseOf: _AppleFirebase.new);

      await sut.loginWithApple();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(apple.shown, 1);
      expect(
        firebase.redeemed.single,
        isA<fb.OAuthCredential>().having((c) => c.idToken, 'idToken', 'apple-token-1'),
      );
      expect(sut.user?.id, 'acct-1');
      expect(sut.isAnonymous, isFalse);
      // the session's store follows the account as a takeover's does
      expect(events, ['link anon-1→acct-1 allowed=false', 'user acct-1', 'enter acct-1']);
      expect(reported.arrivals, ['takeover']);
    });

    test('a new Apple account from the anonymous session moves the store to its uid', () async {
      final sut = await build((_) => _NeverLinked(), firebaseOf: () => _AppleFirebase(newAccount: true));

      await sut.loginWithApple();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(apple.shown, 1);
      expect(sut.user?.id, 'apple-new');
      expect(events, ['link anon-1→apple-new allowed=false', 'user apple-new', 'enter apple-new']);
      expect(reported.arrivals, ['moved'], reason: 'new, but the uid changed: not a link');
    });

    test('a Google account is not asked again: its credential survives a second use', () async {
      final sut = await build((auth) => _TakenCredential(auth, code: 'email-already-in-use'));

      await sut.loginWithGoogle();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.user?.id, 'acct-1');
      expect(apple.shown, 0);
    });

    test('an Apple email already under another sign-in is refused with words the page can show', () async {
      final errors = <Object>[];
      final sut = await build(
        (auth) => _TakenCredential(auth, code: 'email-already-in-use'),
        onError: errors.add,
        firebaseOf: _RefusingFirebase.new,
      );

      await expectLater(
        sut.loginWithApple(),
        throwsA(isA<AuthException>().having((e) => e.reason, 'reason', AuthExceptionReason.accountUnderOtherProvider)),
      );

      expect(apple.shown, 1);
      expect(sut.isAnonymous, isTrue, reason: 'the leg is put back');
      expect(remote.replaying, isFalse);
      expect(errors, hasLength(1), reason: 'still reported: it is worth knowing how often');
    });

    test('a link that fails for any other reason puts the leg back, links nothing, and says so', () async {
      final errors = <Object>[];
      final sut = await build((_) => _UnlinkableAnonymous(), onError: errors.add);

      // reported, and thrown as the reason the page can word: a sign-in
      // that silently stopped is one the user cannot tell from a hang
      await expectLater(
        sut.loginWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.reason, 'reason', AuthExceptionReason.networkRequestFailed)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.isAnonymous, isTrue);
      expect(events, isEmpty, reason: 'nothing was linked, nobody was told');
      expect(remote.replaying, isFalse);
      expect(remote.allowed, isFalse, reason: 'still anonymous');
      expect(errors, hasLength(1));
    });

    test('logging in with email from an anonymous session is the uid-changing case', () async {
      final sut = await build(_TakenCredential.new);

      await sut.logInWithEmailAndPassword(email: 'acct@test', password: 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.user?.id, 'acct-1');
      expect(events, ['link anon-1→acct-1 allowed=false', 'user acct-1', 'enter acct-1']);
      expect(events.where((each) => each.startsWith('enter')), hasLength(1), reason: 'started up once, after the move');
      expect(remote.allowed, isFalse);
    });

    test('signing up with email from an anonymous session links onto it: the uid survives', () async {
      final sut = await build(_LinkableAnonymous.new);

      await sut.signUpWithEmailAndPassword(email: 'new@test', password: 'Str0ng!Passw0rd', name: 'New');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.user?.id, 'anon-1');
      expect(sut.isAnonymous, isFalse);
      expect(events.first, 'link anon-1→anon-1 allowed=false');
      expect(events.where((each) => each.startsWith('enter')), hasLength(1));
      expect(remote.replaying, isTrue);
    });

    test('a sign-in with no anonymous session behind it links nothing and holds nothing', () async {
      final firebase = MockFirebaseAuth(signedIn: false);
      final sut = Auth(
        service: account,
        firebase: firebase,
        remote: remote = RemoteAccess(),
        isWeb: true,
        googleSignIn: MockGoogleSignIn(),
        onLink: (_, _) async => fail('there was no session to link'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sut.isLoggedIn, isFalse);

      await firebase.signInWithCredential(fb.GoogleAuthProvider.credential(idToken: 'token', accessToken: 'access'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sut.isLoggedIn, isTrue);
      expect(remote.replaying, isFalse);
      expect(remote.allowed, isTrue);
    });
  });

  group('eraseSession', () {
    test('wipes the anonymous uid, signs out, and a fresh anonymous session follows', () async {
      final firebase = MockFirebaseAuth(signedIn: false);
      final erased = <String>[];
      final uids = <String?>[];

      final sut = Auth(
        service: account,
        firebase: firebase,
        googleSignIn: MockGoogleSignIn(),
        onErase: (uid) async => erased.add(uid),
        onUserChange: (user) => uids.add(user?.id),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final before = sut.user!.id;

      await sut.eraseSession();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(erased, [before], reason: 'the store is wiped under the uid that held it, once');
      // signed out, then a new anonymous user minted on the spot
      expect(uids, contains(null));
      expect(sut.isLoggedIn, isTrue);
      expect(sut.isAnonymous, isTrue);
    });

    test('wipes the store before the session goes, so the uid is still there to key on', () async {
      final firebase = MockFirebaseAuth(signedIn: false);
      late bool signedInWhileErasing;

      final sut = Auth(
        service: account,
        firebase: firebase,
        googleSignIn: MockGoogleSignIn(),
        onErase: (_) async => signedInWhileErasing = firebase.currentUser != null,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sut.eraseSession();

      expect(signedInWhileErasing, isTrue);
    });

    test('refuses a session with an account behind it: nothing wiped, nobody signed out', () async {
      final firebase = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      );
      final google = MockGoogleSignIn();
      var erased = 0;

      final sut = Auth(
        service: account,
        firebase: firebase,
        googleSignIn: google,
        onErase: (_) async => erased++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sut.eraseSession();

      expect(erased, 0, reason: 'an account\'s mirror is a copy of what the server keeps');
      expect(sut.isLoggedIn, isTrue);
      expect(sut.isAnonymous, isFalse);
      verifyNever(google.signOut());
    });
  });

  group('onSignOut', () {
    test('completes without throwing', () async {
      final firebase = MockFirebaseAuth();
      final google = MockGoogleSignIn();
      final sut = Auth(service: account, firebase: firebase, googleSignIn: google);

      await sut.onSignOut();

      verify(google.signOut()).called(1);
    });
  });

  group('sign-ins on one account (#323)', () {
    late _Account user;
    late MockFirebaseAuth firebase;
    late MockGoogleSignIn google;
    late _AppleSheet apple;
    late ReportedAnalytics reported;
    late List<Object> errors;

    Auth build({List<String> providers = const ['google.com']}) {
      user = _Account(uid: 'acct-1', email: 'acct@test', providers: providers);
      firebase = MockFirebaseAuth(signedIn: true, mockUser: user);
      google = MockGoogleSignIn();
      when(google.initialize()).thenAnswer((_) async {});
      when(google.authenticate(scopeHint: anyNamed('scopeHint'))).thenAnswer((_) async => _GoogleAccount());
      apple = _AppleSheet();
      reported = ReportedAnalytics();
      errors = [];
      when(account.isAuthenticated).thenReturn(true);
      when(account.registerAccount(any)).thenAnswer((inv) async => inv.positionalArguments.first as User);
      return Auth(
        service: account,
        firebase: firebase,
        googleSignIn: google,
        appleCredentials: apple.call,
        analytics: Analytics(service: reported),
        onError: (error, {stacktrace}) => errors.add(error),
      );
    }

    test('the providers are what Firebase lists on the account', () {
      final sut = build(providers: const ['google.com', 'password']);
      expect(sut.providers, {AuthProvider.google, AuthProvider.password});
      expect(sut.providerEmail(.google), 'acct@test');
    });

    test('connecting Apple shows its sheet once and links the token onto the same uid', () async {
      final sut = build();
      var notified = 0;
      sut.addListener(() => notified++);

      await sut.connect(.apple);

      expect(apple.shown, 1);
      expect(user.linked.single.providerId, 'apple.com');
      expect(sut.providers, {AuthProvider.google, AuthProvider.apple});
      expect(notified, greaterThanOrEqualTo(1));
      expect(reported.names, contains('sign_in_connected'));
    });

    test('connecting Google links the account Google answered with', () async {
      final sut = build(providers: const ['apple.com']);

      await sut.connect(.google);

      expect(user.linked.single.providerId, 'google.com');
      expect(sut.providers, {AuthProvider.apple, AuthProvider.google});
    });

    test('a provider that is already a Heart account of its own is refused with words', () async {
      final sut = build();
      user.refusal = fb.FirebaseAuthException(code: 'credential-already-in-use');

      await expectLater(
        sut.connect(.apple),
        throwsA(isA<AuthException>().having((e) => e.reason, 'reason', AuthExceptionReason.providerInUse)),
      );
      expect(sut.providers, {AuthProvider.google});
      expect(errors, hasLength(1));
    });

    test('backing out of the sheet connects nothing and says nothing', () async {
      final sut = build();
      when(
        google.authenticate(scopeHint: anyNamed('scopeHint')),
      ).thenThrow(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));

      await sut.connect(.google);

      expect(user.linked, isEmpty);
      expect(errors, isEmpty);
    });

    test('disconnecting leaves the account with the other sign-in, never with none', () async {
      final sut = build(providers: const ['google.com', 'apple.com']);

      await sut.disconnect(.google);
      expect(sut.providers, {AuthProvider.apple});
      expect(reported.names, contains('sign_in_disconnected'));

      await sut.disconnect(.apple);
      expect(sut.providers, {AuthProvider.apple}, reason: 'the last sign-in stays');
    });

    test('a refused provider sign-in is connected once the person is in the other way', () async {
      // an anonymous session, as the login page sees it
      final otherProvider = _OtherProviderFirebase();
      otherProvider.mockUser = _TakenCredential(otherProvider, code: 'email-already-in-use');
      google = MockGoogleSignIn();
      when(google.initialize()).thenAnswer((_) async {});
      when(google.authenticate(scopeHint: anyNamed('scopeHint'))).thenAnswer((_) async => _GoogleAccount());
      when(account.isAuthenticated).thenReturn(true);
      when(account.registerAccount(any)).thenAnswer((inv) async => inv.positionalArguments.first as User);
      reported = ReportedAnalytics();
      final sut = Auth(
        service: account,
        firebase: otherProvider,
        googleSignIn: google,
        analytics: Analytics(service: reported),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await expectLater(
        sut.loginWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.reason, 'reason', AuthExceptionReason.accountUnderOtherProvider)),
      );

      await sut.logInWithEmailAndPassword(email: 'acct@test', password: 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // the mock's password sign-in mints its own user object, so the link
      // is observed through what it reports rather than through the fake
      expect(
        reported.names.where((name) => name == 'sign_in_connected'),
        hasLength(1),
        reason: 'the refused Google sign-in, connected onto the account it landed in',
      );
      expect(sut.isAnonymous, isFalse);
    });
  });
}
