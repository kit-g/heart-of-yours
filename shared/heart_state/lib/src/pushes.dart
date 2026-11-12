import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'coaching.dart';
import 'remote.dart';

/// What the server does with the push client (heart-of-yours#567, #554).
///
/// Defined here, like `CoachingService`: the app's view of a few routes, which
/// it adapts `Api` onto.
abstract interface class RemotePushService {
  /// Registers [token] for the signed-in account. Safe to repeat.
  Future<void> registerDevice({required DevicePlatform platform, required String token, int? utcOffsetMinutes});

  /// Stops [token] getting the signed-in account's pushes. Safe to repeat.
  Future<void> unregisterDevice(String token);

  Future<PushSettings> getPushSettings();

  /// [connectionId] narrows the answer to one person.
  Future<void> setPushSetting(String topic, String delivery, {String? connectionId});

  /// Back to the default: the server's for a topic, the topic's for a person.
  Future<void> clearPushSetting(String topic, {String? connectionId});
}

/// The topics this build acts on, by the server's name for each.
///
/// The server may send ones this build has never heard of: such a push still
/// shows, and its setting still lists and changes, because the server words
/// both. Only what a push *does* on a tap, or silently, needs a name here.
enum PushTopic {
  /// Someone commented on something of the account's. Carries `targetType`
  /// and `targetId`, never the words.
  commentCreated('comment.created'),

  /// A message arrived in `threadId`.
  coachingMessage('coaching.message'),

  /// Someone accepted the coach's invitation.
  invitationAccepted('coaching.invitation_accepted'),

  /// A coach's send made the student a new copy, `programId`.
  programReceived('coaching.program_received'),

  /// Once an evening, when the coach's clients trained.
  workoutDigest('coaching.workout_digest'),

  /// The other person changed a managed copy, `programId`. Silent.
  programChanged('coaching.program_changed', silent: true),

  /// The other person deleted the conversation `threadId`. Silent.
  threadCleared('coaching.thread_cleared', silent: true),

  /// Someone the app shares keys with, `userId`, added or removed a device.
  /// Silent.
  devicesChanged('security.devices_changed', silent: true);

  final String value;

  /// Shows nothing: it only tells the app what to fetch.
  final bool silent;

  new(this.value, {this.silent = false});

  static PushTopic? of(String value) => values.where((each) => each.value == value).firstOrNull;
}

/// A push as it reached the device: its topic and the ids it carries.
///
/// Never words: a push says who, never what, and whatever title the server
/// rendered is the system's to show, not the app's to read.
class Push {
  /// The server's name for it, kept even when this build does not know it.
  final String topic;

  /// Everything the push carries besides its topic, as the server sent it.
  final Map<String, String> data;

  const new({required this.topic, this.data = const {}});

  /// The data of a push, as FCM hands it over: null for one with no topic,
  /// which is not one of the server's.
  static Push? of(Map data) {
    return switch (data['topic']) {
      final String topic when topic.isNotEmpty => Push(
        topic: topic,
        data: {
          for (final MapEntry(:key, :value) in data.entries)
            if (key != 'topic' && value != null) '$key': '$value',
        },
      ),
      _ => null,
    };
  }

  PushTopic? get known => PushTopic.of(topic);

  String? get programId => data['programId'];

  String? get threadId => data['threadId'];

  String? get userId => data['userId'];

  Map<String, String> toMap() => {'topic': topic, ...data};
}

/// The deliveries this build has words for. The vocabulary is the server's
/// and open: one this build does not know is offered nowhere and kept as it
/// is.
enum PushDelivery {
  instant,
  daily,
  off;

  static PushDelivery? of(String value) => values.where((each) => each.name == value).firstOrNull;
}

/// The push client's state: whether this device is registered with the
/// server, and what reaches the account, topic by topic and person by person.
///
/// Server-only, like `Coaching`: the settings are the server's to keep, and
/// the screen draws them from its answer, so a topic this build has never
/// heard of still shows and changes. Nothing here runs until the app turns the
/// push client on, which it does only with a coaching switch on.
class Pushes with ChangeNotifier implements SignOutStateSentry {
  final RemotePushService _service;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({required this._service, RemoteAccess? remote, this.onError}) : _remote = remote ?? RemoteAccess();

  static Pushes of(BuildContext context) => Provider.of<Pushes>(context, listen: false);

  static Pushes watch(BuildContext context) => Provider.of<Pushes>(context, listen: true);

  /// What was last registered, so a launch registers once rather than at
  /// every notification of the account.
  ({String token, int? offset})? _registered;

  /// The token last handed to [register], whether or not that registration
  /// went through: a launch before it may have, and [unregister] takes it
  /// back.
  String? _token;

  /// How long a sign-out or a stop waits on the server to take a token back.
  static const _removalWait = Duration(seconds: 5);

  final _topics = <PushSetting>[];
  final _people = <PushPreference>[];
  CoachingStatus _status = .idle;

  CoachingStatus get status => _status;

  /// Every topic the account can change, in the server's order.
  List<PushSetting> get topics => UnmodifiableListView(_topics);

  /// What was said about [topic] for one person, or null when they follow the
  /// topic.
  String? deliveryFor(String topic, String connectionId) {
    return _people.where((each) => each.topic == topic && each.connectionId == connectionId).firstOrNull?.delivery;
  }

  /// Every answer given about one person.
  Iterable<PushPreference> get forPeople => UnmodifiableListView(_people);

  @override
  void onSignOut() {
    _registered = null;
    _token = null;
    _topics.clear();
    _people.clear();
    _status = .idle;
    notifyListeners();
  }

  /// Tells the server this device's [token] belongs to the signed-in account.
  /// Again only when the token or the offset changed: a phone that crossed a
  /// time zone has a new evening. A failure is reported and forgotten; the
  /// next launch registers again.
  Future<void> register({required DevicePlatform platform, required String token, int? utcOffsetMinutes}) async {
    if (!_remote.allowed) return;
    _token = token;
    final registering = (token: token, offset: utcOffsetMinutes);
    if (registering == _registered) return;
    _registered = registering;
    try {
      await _service.registerDevice(platform: platform, token: token, utcOffsetMinutes: utcOffsetMinutes);
    } catch (error, stacktrace) {
      _registered = null;
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Tells the server this device no longer gets the account's pushes
  /// (heart-api#415), taking back the token [register] was last given, once.
  ///
  /// On a sign-out, while the session can still say whose pushes they are,
  /// and when pushes turn off, before the token is deleted. Either way the next
  /// token is registered whatever it is. Nothing is sent when no token was
  /// given or the server is out of reach; a removal that fails, or keeps the
  /// caller waiting past [_removalWait], is reported and left: the token is
  /// deleted on the device all the same, and the server drops one it never
  /// sees again.
  Future<void> unregister() async {
    final token = _token;
    _token = null;
    _registered = null;
    if (token == null || !_remote.allowed) return;
    try {
      await _service.unregisterDevice(token).timeout(_removalWait);
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Reads what reaches the account.
  Future<void> load() async {
    if (!_remote.allowed) return;
    _status = .loading;
    notifyListeners();
    try {
      final PushSettings(:topics, :forPeople) = await _service.getPushSettings();
      _topics
        ..clear()
        ..addAll(topics);
      _people
        ..clear()
        ..addAll(forPeople);
      _status = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _status = .failed;
    }
    notifyListeners();
  }

  /// Sets how [topic] reaches the account. Shown at once, and put back if the
  /// server refuses, with what it threw rethrown for the caller to say so.
  Future<void> set(String topic, String delivery) async {
    final index = _topics.indexWhere((each) => each.topic == topic);
    if (index == -1) return;
    final was = _topics[index];
    if (was.delivery == delivery) return;
    // through its own map, so a field a later heart_models adds is carried
    _topics[index] = PushSetting.fromJson({...was.toMap(), 'delivery': delivery});
    notifyListeners();
    try {
      await _service.setPushSetting(topic, delivery);
    } catch (_) {
      _topics[index] = was;
      notifyListeners();
      rethrow;
    }
  }

  /// Sets how [topic] reaches the account from one person, or, with null,
  /// lets them follow the topic again. Optimistic like [set].
  Future<void> setFor(String topic, String connectionId, String? delivery) async {
    final was = [..._people];
    _people.removeWhere((each) => each.topic == topic && each.connectionId == connectionId);
    if (delivery case final String delivery) {
      _people.add((topic: topic, connectionId: connectionId, delivery: delivery));
    }
    notifyListeners();
    try {
      switch (delivery) {
        case final String delivery:
          await _service.setPushSetting(topic, delivery, connectionId: connectionId);
        case null:
          await _service.clearPushSetting(topic, connectionId: connectionId);
      }
    } catch (_) {
      _people
        ..clear()
        ..addAll(was);
      notifyListeners();
      rethrow;
    }
  }
}
