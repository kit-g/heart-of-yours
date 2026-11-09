import 'native.dart';

/// A public key and the id the account knows it by.
typedef PublicKey = ({String id, String key});

/// A message in a pairwise session: `type` 0 is the first, which starts the
/// session on the other side, and 1 is every later one.
typedef PairwiseMessage = ({int type, String body});

/// End-to-end encryption between devices.
///
/// Every piece of state (an account, a session, a thread key) comes back from
/// a call sealed under [storageKey], and goes back in on the next call. Where
/// it lives, and how anything travels, is the caller's business. Save what a
/// call returns before acting on anything else it returns: state that isn't
/// saved is state that gets used twice.
///
/// [storageKey] is 32 bytes of base64 that the caller keeps out of backups,
/// in the Keychain or the Keystore.
final class Sealbox {
  const new(this.storageKey);

  final String storageKey;

  Map<String, Object?> _call(String op, [Map<String, Object?> arguments = const {}]) =>
      call(op, {'storageKey': storageKey, ...arguments});

  // ---- a device's account ----

  /// A device's identity, signing key, first [oneTimeKeys] one-time keys and a
  /// fallback key. The public keys are for the server; [account] is for storage.
  ({
    String account,
    String identityKey,
    String signingKey,
    List<PublicKey> oneTimeKeys,
    PublicKey fallbackKey,
  })
  createAccount({int oneTimeKeys = 20}) {
    final answer = _call('accountNew', {'oneTimeKeys': oneTimeKeys});
    return (
      account: answer['account'] as String,
      identityKey: answer['identityKey'] as String,
      signingKey: answer['signingKey'] as String,
      oneTimeKeys: _keys(answer['oneTimeKeys']),
      fallbackKey: _key(answer['fallbackKey']),
    );
  }

  ({String identityKey, String signingKey, int storedOneTimeKeys}) accountKeys(String account) {
    final answer = _call('accountKeys', {'account': account});
    return (
      identityKey: answer['identityKey'] as String,
      signingKey: answer['signingKey'] as String,
      storedOneTimeKeys: answer['storedOneTimeKeys'] as int,
    );
  }

  /// [count] more one-time keys, up to [maxOneTimeKeys] held at once.
  ({String account, List<PublicKey> oneTimeKeys}) generateOneTimeKeys(String account, int count) {
    final answer = _call('accountOneTimeKeys', {'account': account, 'count': count});
    return (account: answer['account'] as String, oneTimeKeys: _keys(answer['oneTimeKeys']));
  }

  ({String account, PublicKey fallbackKey}) rotateFallbackKey(String account) {
    final answer = _call('accountFallbackKey', {'account': account});
    return (account: answer['account'] as String, fallbackKey: _key(answer['fallbackKey']));
  }

  /// A signature anyone holding this device's signing key can check, as an old
  /// device signs a new one's identity key to vouch for it.
  String sign(String account, String message) =>
      _call('accountSign', {'account': account, 'message': message})['signature'] as String;

  static bool verifySignature({required String signingKey, required String message, required String signature}) =>
      call('verifySignature', {'signingKey': signingKey, 'message': message, 'signature': signature})['valid'] as bool;

  /// A device holds at most this many unused one-time keys.
  static const maxOneTimeKeys = 50;

  // ---- a pairwise session between two devices ----

  /// Starts a session to another device, from its identity key and one of its
  /// one-time keys (or its fallback key, once those run out).
  ({String session, String sessionId}) startSession({
    required String account,
    required String identityKey,
    required String oneTimeKey,
  }) {
    final answer = _call('sessionOutbound', {'account': account, 'identityKey': identityKey, 'oneTimeKey': oneTimeKey});
    return (session: answer['session'] as String, sessionId: answer['sessionId'] as String);
  }

  /// Accepts a session another device started, from its first message. The
  /// account changes, since the one-time key it used is spent.
  ({String account, String session, String sessionId, String plaintext}) acceptSession({
    required String account,
    required String identityKey,
    required PairwiseMessage message,
  }) {
    final answer = _call('sessionInbound', {
      'account': account,
      'identityKey': identityKey,
      'message': _message(message),
    });
    return (
      account: answer['account'] as String,
      session: answer['session'] as String,
      sessionId: answer['sessionId'] as String,
      plaintext: answer['plaintext'] as String,
    );
  }

  ({String session, PairwiseMessage message}) encrypt(String session, String plaintext) {
    final answer = _call('sessionEncrypt', {'session': session, 'plaintext': plaintext});
    return (session: answer['session'] as String, message: _toMessage(answer['message']));
  }

  /// A pairwise message opens once. Read them in order: only a short run of
  /// skipped ones can be recovered.
  ({String session, String plaintext}) decrypt(String session, PairwiseMessage message) {
    final answer = _call('sessionDecrypt', {'session': session, 'message': _message(message)});
    return (session: answer['session'] as String, plaintext: answer['plaintext'] as String);
  }

  /// The session a first message belongs to, so a device holding several can
  /// tell whether it already accepted this one. Null for any later message.
  static String? sessionIdOf(PairwiseMessage message) =>
      call('messageSessionId', {'message': _message(message)})['sessionId'] as String?;

  // ---- a stored thread: one copy, readable by every device holding its key ----

  /// A new thread key. [outbound] seals; [sessionKey] goes to every device
  /// allowed to read, inside pairwise sessions.
  ({String outbound, String sessionId, String sessionKey}) newThread() {
    final answer = _call('threadNew');
    return (
      outbound: answer['outbound'] as String,
      sessionId: answer['sessionId'] as String,
      sessionKey: answer['sessionKey'] as String,
    );
  }

  /// Seals one message to a thread. Store [outbound] before sending: an old
  /// one would reuse [messageIndex].
  ({String outbound, String ciphertext, String sessionId, int messageIndex}) sealToThread(
    String outbound,
    String plaintext,
  ) {
    final answer = _call('threadEncrypt', {'outbound': outbound, 'plaintext': plaintext});
    return (
      outbound: answer['outbound'] as String,
      ciphertext: answer['ciphertext'] as String,
      sessionId: answer['sessionId'] as String,
      messageIndex: answer['messageIndex'] as int,
    );
  }

  /// A reader for a thread, from the key its sender shared.
  ({String inbound, String sessionId, int firstKnownIndex}) joinThread(String sessionKey) =>
      _reader(_call('threadInbound', {'sessionKey': sessionKey}));

  /// A reader from a key another reader exported, as a new device catches up.
  ({String inbound, String sessionId, int firstKnownIndex}) importThread(String exportedKey) =>
      _reader(_call('threadImport', {'exportedKey': exportedKey}));

  /// This reader's key from [fromIndex] on, or from as far back as it reaches.
  String exportThread(String inbound, {int? fromIndex}) =>
      _call('threadExport', {'inbound': inbound, 'fromIndex': ?fromIndex})['exportedKey'] as String;

  /// Opens one thread message, in any order and as often as needed. The
  /// library opens two different messages at the same [messageIndex]; the
  /// caller has to refuse the second.
  ({String inbound, String plaintext, int messageIndex, String sessionId}) openFromThread(
    String inbound,
    String ciphertext,
  ) {
    final answer = _call('threadDecrypt', {'inbound': inbound, 'ciphertext': ciphertext});
    return (
      inbound: answer['inbound'] as String,
      plaintext: answer['plaintext'] as String,
      messageIndex: answer['messageIndex'] as int,
      sessionId: answer['sessionId'] as String,
    );
  }

  // ---- fingerprints ----

  /// 22 URL-safe characters naming a device's keys, under the caller's
  /// [context], short enough to ride in a link's fragment.
  static String fingerprint({required String identityKey, required String signingKey, required String context}) =>
      call('fingerprint', {'identityKey': identityKey, 'signingKey': signingKey, 'context': context})['fingerprint']
          as String;

  // ---- sealing to oneself ----

  static String newNoteKey() => call('noteKey')['key'] as String;

  /// Sealed under [key], bound to [context]: it opens with both, and nothing else.
  static String sealNote({required String key, required String context, required String plaintext}) =>
      call('noteSeal', {'key': key, 'context': context, 'plaintext': plaintext})['sealed'] as String;

  static String openNote({required String key, required String context, required String sealed}) =>
      call('noteOpen', {'key': key, 'context': context, 'sealed': sealed})['plaintext'] as String;

  // ---- franking: proving later what was said ----

  /// What to encrypt in place of [plaintext], and the commitment to send beside
  /// it: HMAC-SHA256 of the UTF-8 words under a fresh key, in base64.
  static ({String inner, String commitment}) frank(String plaintext) {
    final answer = call('frank', {'plaintext': plaintext});
    return (inner: answer['inner'] as String, commitment: answer['commitment'] as String);
  }

  /// Opens what a decryption gave back, and checks it against the commitment
  /// that travelled beside it. Keep [frankingKey]: a report needs it.
  static ({String plaintext, String frankingKey}) openFranked({required String inner, required String commitment}) {
    final answer = call('frankOpen', {'inner': inner, 'commitment': commitment});
    return (plaintext: answer['plaintext'] as String, frankingKey: answer['frankingKey'] as String);
  }

  static bool verifyFranked({required String frankingKey, required String plaintext, required String commitment}) =>
      call('frankVerify', {'frankingKey': frankingKey, 'plaintext': plaintext, 'commitment': commitment})['valid']
          as bool;
}

/// Two people comparing a code, to know no one sits between their devices.
///
/// The order matters, because whoever moves the keys could otherwise wait for
/// one side's key and grind its own until the codes match. The side that will
/// see the other's key first sends its [commitment] before anything else; the
/// other then sends its [publicKey]; then the first sends its own, and the
/// second checks it against the commitment in [establish]. Matrix's
/// comparison runs the same way.
///
/// Lives in memory only: [end] it when done, and start over after a restart.
/// One dropped without [end] is ended when it is collected, and at most 16 run
/// at once.
final class Comparison {
  new _(this._id, this.publicKey, this.commitment) {
    _finalizer.attach(this, _id, detach: this);
  }

  static final _finalizer = Finalizer<int>((id) => call('comparisonEnd', {'comparison': id}));

  /// Starts one. `too_many_comparisons` while 16 are already running.
  factory start() {
    final answer = call('comparisonStart');
    return Comparison._(
      answer['comparison'] as int,
      answer['publicKey'] as String,
      answer['commitment'] as String,
    );
  }

  final int _id;

  /// Send it to the other device, after its commitment, if it sends one.
  final String publicKey;

  /// A hash of [publicKey], sent before it by the side that will see the other
  /// key first.
  final String commitment;

  /// Takes the other device's public key, checking it against the
  /// [theirCommitment] it sent first, when it did. A key that doesn't match
  /// throws `commitment_mismatch` and ends the comparison.
  void establish(String theirPublicKey, {String? theirCommitment}) => call('comparisonEstablish', {
    'comparison': _id,
    'publicKey': theirPublicKey,
    'commitment': ?theirCommitment,
  });

  /// The code both screens show under the same [info]: three numbers, and the
  /// same as seven emoji indices.
  ({List<int> decimals, List<int> emoji}) code(String info) {
    final answer = call('comparisonCode', {'comparison': _id, 'info': info});
    return (decimals: _ints(answer['decimals']), emoji: _ints(answer['emoji']));
  }

  /// A MAC over [input] under the shared secret, so the other side can tell it
  /// came from this device, such as a new device's identity key.
  String mac(String input, String info) =>
      call('comparisonMac', {'comparison': _id, 'input': input, 'info': info})['mac'] as String;

  bool verifyMac(String input, String info, String mac) =>
      call('comparisonVerifyMac', {'comparison': _id, 'input': input, 'info': info, 'mac': mac})['valid'] as bool;

  void end() {
    _finalizer.detach(this);
    call('comparisonEnd', {'comparison': _id});
  }
}

Map<String, Object?> _message(PairwiseMessage message) => {'type': message.type, 'body': message.body};

PairwiseMessage _toMessage(Object? json) => switch (json) {
  {'type': final int type, 'body': final String body} => (type: type, body: body),
  _ => throw ArgumentError.value(json, 'message'),
};

PublicKey _key(Object? json) => switch (json) {
  {'id': final String id, 'key': final String key} => (id: id, key: key),
  _ => throw ArgumentError.value(json, 'key'),
};

List<PublicKey> _keys(Object? json) => (json as List<Object?>).map(_key).toList();

List<int> _ints(Object? json) => List.unmodifiable((json as List<Object?>).cast<int>());

({String inbound, String sessionId, int firstKnownIndex}) _reader(Map<String, Object?> answer) => (
  inbound: answer['inbound'] as String,
  sessionId: answer['sessionId'] as String,
  firstKnownIndex: answer['firstKnownIndex'] as int,
);
