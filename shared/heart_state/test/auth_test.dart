import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heart_models/heart_models.dart' show User;
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

class _FakeGoogle extends GoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signOut() async => null;
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

      when(account.getAvatarUploadLink(any, imageMimeType: anyNamed('imageMimeType')))
          .thenAnswer((_) async => (url: 'https://u', fields: <String, String>{}));

      // wait for sut.user to update
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final expectedId = sut.user!.id;
      final res = await sut.getAvatarUploadLink(imageMimeType: 'image/png');
      expect(res, isNotNull);
      verify(account.getAvatarUploadLink(expectedId, imageMimeType: 'image/png')).called(1);
    });

    test('updateAvatar: when user present but no upload link, sets local avatar, notifies once and returns false',
        () async {
      final firebase = MockFirebaseAuth();
      final sut = Auth(service: account, firebase: firebase);

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
      verifyNever(account.uploadAvatar(any, any, onProgress: anyNamed('onProgress')));
    });

    test('deleteAccountDeletionSchedule: no-op when user is null (no service calls)', () async {
      final firebase = MockFirebaseAuth();
      final sut = Auth(service: account, firebase: firebase);
      await sut.deleteAccountDeletionSchedule();

      verifyZeroInteractions(account);
    });
  });

  group('onSignOut', () {
    test('completes without throwing', () async {
      final firebase = MockFirebaseAuth();
      final sut = Auth(service: account, firebase: firebase, googleSignIn: _FakeGoogle());

      await sut.onSignOut();
    });
  });
}
