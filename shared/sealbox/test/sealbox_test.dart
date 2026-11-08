import 'dart:convert';

import 'package:sealbox/sealbox.dart';
import 'package:test/test.dart';

void main() {
  final box = Sealbox(base64.encode(List.filled(32, 9)));

  group('a pairwise session', () {
    test('carries words both ways between two devices', () {
      final alice = box.createAccount(oneTimeKeys: 3);
      final bob = box.createAccount(oneTimeKeys: 3);
      expect(bob.oneTimeKeys, hasLength(3));

      final started = box.startSession(
        account: alice.account,
        identityKey: bob.identityKey,
        oneTimeKey: bob.oneTimeKeys.first.key,
      );
      final hello = box.encrypt(started.session, 'hello');
      expect(hello.message.type, 0);
      expect(Sealbox.sessionIdOf(hello.message), started.sessionId);

      final accepted = box.acceptSession(account: bob.account, identityKey: alice.identityKey, message: hello.message);
      expect(accepted.plaintext, 'hello');
      expect(box.accountKeys(accepted.account).storedOneTimeKeys, 2);

      final reply = box.encrypt(accepted.session, 'hi, Muffin');
      expect(Sealbox.sessionIdOf(reply.message), isNull);
      expect(box.decrypt(hello.session, reply.message).plaintext, 'hi, Muffin');
    });

    test('a message opens once', () {
      final alice = box.createAccount(oneTimeKeys: 1);
      final bob = box.createAccount(oneTimeKeys: 1);
      final started = box.startSession(
        account: alice.account,
        identityKey: bob.identityKey,
        oneTimeKey: bob.oneTimeKeys.single.key,
      );
      final hello = box.encrypt(started.session, 'hello');
      final accepted = box.acceptSession(account: bob.account, identityKey: alice.identityKey, message: hello.message);
      final next = box.encrypt(hello.session, 'once');
      final read = box.decrypt(accepted.session, next.message);
      expect(read.plaintext, 'once');
      expect(
        () => box.decrypt(read.session, next.message),
        throwsA(isA<SealboxException>().having((e) => e.code, 'code', 'decrypt_failed')),
      );
    });
  });

  group('a thread', () {
    test('reads newest first, on a device let in later', () {
      final thread = box.newThread();
      var outbound = thread.outbound;
      final stored = <String>[];
      for (final i in Iterable<int>.generate(5)) {
        final sealed = box.sealToThread(outbound, 'm$i');
        expect(sealed.messageIndex, i);
        outbound = sealed.outbound;
        stored.add(sealed.ciphertext);
      }

      final phone = box.joinThread(thread.sessionKey);
      final tablet = box.importThread(box.exportThread(phone.inbound));
      expect(tablet.sessionId, thread.sessionId);

      var inbound = tablet.inbound;
      for (final (i, ciphertext) in stored.indexed.toList().reversed) {
        final read = box.openFromThread(inbound, ciphertext);
        expect((read.plaintext, read.messageIndex), ('m$i', i));
        inbound = read.inbound;
      }

      final late = box.importThread(box.exportThread(phone.inbound, fromIndex: 3));
      expect(late.firstKnownIndex, 3);
      expect(() => box.openFromThread(late.inbound, stored[2]), throwsA(isA<SealboxException>()));
    });
  });

  test('an old device vouches for a new one after comparing a code', () {
    final old = box.createAccount(oneTimeKeys: 1);
    final fresh = box.createAccount(oneTimeKeys: 1);
    final one = Comparison.start();
    final two = Comparison.start();
    addTearDown(one.end);
    addTearDown(two.end);
    one.establish(two.publicKey);
    two.establish(one.publicKey);
    final (mine, theirs) = (one.code('add a device'), two.code('add a device'));
    expect(mine.decimals, theirs.decimals);
    expect(mine.emoji, theirs.emoji);

    final mac = two.mac(fresh.identityKey, 'identity');
    expect(one.verifyMac(fresh.identityKey, 'identity', mac), isTrue);
    expect(one.verifyMac(old.identityKey, 'identity', mac), isFalse);

    final signature = box.sign(old.account, fresh.identityKey);
    expect(
      Sealbox.verifySignature(signingKey: old.signingKey, message: fresh.identityKey, signature: signature),
      isTrue,
    );
    expect(
      Sealbox.verifySignature(signingKey: old.signingKey, message: old.identityKey, signature: signature),
      isFalse,
    );
  });

  test('a fingerprint fits a link and depends on the context', () {
    final device = box.createAccount(oneTimeKeys: 1);
    String print(String context) =>
        Sealbox.fingerprint(identityKey: device.identityKey, signingKey: device.signingKey, context: context);
    expect(print('an app'), print('an app'));
    expect(print('an app'), isNot(print('another app')));
    expect(print('an app'), matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
  });

  test('a note opens with its key and context only', () {
    final key = Sealbox.newNoteKey();
    final sealed = Sealbox.sealNote(key: key, context: 'notes', plaintext: 'left knee');
    expect(Sealbox.openNote(key: key, context: 'notes', sealed: sealed), 'left knee');
    expect(
      () => Sealbox.openNote(key: key, context: 'drafts', sealed: sealed),
      throwsA(isA<SealboxException>().having((e) => e.code, 'code', 'wont_open')),
    );
  });

  test('franked words survive the thread and check out, and altered ones do not', () {
    final franked = Sealbox.frank('see you Thursday');
    final thread = box.newThread();
    final sealed = box.sealToThread(thread.outbound, franked.inner);
    final read = box.openFromThread(box.joinThread(thread.sessionKey).inbound, sealed.ciphertext);
    final opened = Sealbox.openFranked(inner: read.plaintext, commitment: franked.commitment);
    expect(opened.plaintext, 'see you Thursday');

    bool checks(String words) =>
        Sealbox.verifyFranked(frankingKey: opened.frankingKey, plaintext: words, commitment: franked.commitment);
    expect(checks('see you Thursday'), isTrue);
    expect(checks('see you never'), isFalse);
  });

  test('state sealed under one storage key will not open under another', () {
    final account = box.createAccount(oneTimeKeys: 1).account;
    final other = Sealbox(base64.encode(List.filled(32, 1)));
    expect(
      () => other.accountKeys(account),
      throwsA(isA<SealboxException>().having((e) => e.code, 'code', 'wrong_storage_key')),
    );
  });

  test('a device holds at most fifty one-time keys', () {
    final account = box.createAccount(oneTimeKeys: 5).account;
    final more = box.generateOneTimeKeys(account, 45);
    expect(more.oneTimeKeys, hasLength(45));
    expect(() => box.generateOneTimeKeys(more.account, 1), throwsA(isA<SealboxException>()));
    expect(Sealbox.maxOneTimeKeys, 50);
  });

  test('words outside ASCII round-trip', () {
    const words = 'Ça va? 膝が痛い 🏋️';
    final thread = box.newThread();
    final sealed = box.sealToThread(thread.outbound, words);
    expect(box.openFromThread(box.joinThread(thread.sessionKey).inbound, sealed.ciphertext).plaintext, words);
  });
}
