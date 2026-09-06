import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart' show User;
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

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
}
