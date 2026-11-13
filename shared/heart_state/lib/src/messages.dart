import 'dart:async';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'coaching.dart' show CoachingStatus;
import 'device_keys.dart';
import 'remote.dart';

/// What the server does with threads (heart-of-yours#556). Like
/// [RemoteKeyService], the app's view of a few routes, which the app adapts
/// `Api` onto.
abstract interface class RemoteThreadService {
  Future<Thread> openThread(String connectionId);

  Future<List<Thread>> getThreads();

  Future<ThreadItem> postThreadItem(
    String threadId, {
    required String id,
    required String content,
    required String commitment,
    required DateTime at,
    String? subjectType,
    String? subjectId,
  });

  Future<({List<ThreadItem> items, String? cursor})> getThreadItems(
    String threadId, {
    String? since,
    String? before,
    int? limit,
  });

  Future<void> markThreadRead(String threadId, String cursor);
}

/// One stored item and where it sits: [position] is the server's order as this
/// device met it, null for one written here the server hasn't placed yet;
/// [pending] for one it hasn't taken.
typedef StoredItem = ({ThreadItem item, int? position, bool pending});

/// Where a device keeps threads, so one opens offline: ciphertext only, as
/// the server holds it.
abstract interface class LocalThreadService {
  Future<List<Thread>> getThreads(String userId);

  /// Makes [threads] the whole inbox.
  Future<void> storeThreads(String userId, Iterable<Thread> threads);

  Future<void> storeThread(String userId, Thread thread);

  /// In the server's order, then those it hasn't placed.
  Future<List<StoredItem>> getThreadItems(String userId, String threadId);

  /// Adds, or replaces by id.
  Future<void> storeThreadItems(String userId, Iterable<StoredItem> items);
}

/// Where a message of this device's stands with the server.
enum MessageDelivery {
  /// The server took it.
  sent,

  /// Not yet: no network, the thread's keys not shared yet, or too many at
  /// once. Tried again on its own.
  waiting,

  /// The thread takes nothing more from this person: the connection ended, or
  /// a block stands. Kept here, never sent.
  closed,
}

/// One message as the app shows it.
class Message {
  final ThreadItem item;

  /// Opened, still waiting for its key, or never to open.
  final OpenedMessage opened;

  final bool mine;

  final MessageDelivery delivery;

  const new({required this.item, required this.opened, required this.mine, required this.delivery});

  String get id => item.id;

  /// When its writer wrote it, by their device: what to show. The order is the
  /// server's.
  DateTime get at => item.at;

  String? get text => switch (opened) {
    Opened(:final text) => text,
    Locked() || Refused() => null,
  };
}

/// One thread as this device has read it.
class MessageThread {
  final String threadId;
  final List<Message> messages;
  final CoachingStatus status;

  /// Older messages wait on the server.
  final bool hasOlder;

  /// The server refused a message here: the thread takes nothing more from
  /// this person.
  final bool closed;

  const new({
    required this.threadId,
    this.messages = const [],
    this.status = .idle,
    this.hasOlder = false,
    this.closed = false,
  });
}

/// Coaching messages (heart-of-yours#556): the inbox, each thread, and sending.
///
/// Every message is sealed on this device before it goes anywhere, and what
/// is kept here is what the server keeps: ciphertext. The words are opened in
/// memory, each time a thread is read.
///
/// A message is written here first, then sent: one written offline waits on
/// the device, sealed, and goes when the server can be reached, under the id
/// it was written with, so a retry is never a second message. The order is
/// the server's, never the device's clock.
///
/// Server-backed and opt-in through coaching: nothing here is read or sent
/// unless a screen of a coaching feature asks, and those exist only with a
/// switch on.
class Messages with ChangeNotifier implements SignOutStateSentry {
  final RemoteThreadService _service;
  final LocalThreadService _local;
  final ThreadCipher _cipher;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final String Function() _newId;
  final DateTime Function() _now;

  /// The fingerprint an invitation link carried for the other person of
  /// [thread], to check their devices against before a key reaches them.
  final String? Function(Thread thread)? fingerprintFor;

  new({
    required this._service,
    required this._local,
    required this._cipher,
    RemoteAccess? remote,
    this.onError,
    this.fingerprintFor,
    String Function()? newId,
    DateTime Function()? now,
  }) : _remote = remote ?? RemoteAccess(),
       _newId = newId ?? uuidV7,
       _now = now ?? DateTime.now {
    _keys = _cipher.threadKeys.listen(_keyArrived);
  }

  static Messages of(BuildContext context) => Provider.of<Messages>(context, listen: false);

  static Messages watch(BuildContext context) => Provider.of<Messages>(context, listen: true);

  /// How many items one read asks for.
  static const _page = 50;

  late final StreamSubscription<String> _keys;

  String? _userId;

  String? get userId => _userId;

  set userId(String? value) {
    if (value == _userId) return;
    _forget();
    _userId = value;
  }

  final _threads = <Thread>[];
  final _views = <String, MessageThread>{};
  final _drafts = <String, String>{};
  final _pulls = _OneAtATime();
  final _flushes = _OneAtATime();
  final _writes = _InTurn();
  final _retries = <String, Timer>{};

  /// How many screens show each thread: a thread nobody shows is neither read
  /// on a push nor marked read.
  final _following = <String, int>{};

  /// Whether older messages wait on the server, by thread, once known: kept
  /// when a screen closes, so a thread opened again offers them still.
  final _older = <String, bool>{};

  /// The cursor each thread was last marked read at.
  final _marked = <String, String>{};
  CoachingStatus _status = .idle;

  CoachingStatus get status => _status;

  /// The inbox, last arrival first.
  List<Thread> get threads => List.unmodifiable(_threads);

  /// Unread across the inbox.
  int get unread => _threads.fold(0, (sum, thread) => sum + thread.unread);

  Thread? lookup(String threadId) => _threads.where((each) => each.id == threadId).firstOrNull;

  Thread? threadOf(String connectionId) => _threads.where((each) => each.connectionId == connectionId).firstOrNull;

  MessageThread thread(String threadId) => _views[threadId] ?? MessageThread(threadId: threadId);

  /// What was being written in [threadId] and not sent: kept across a fold,
  /// a rotation, and the screen closing.
  String draft(String threadId) => _drafts[threadId] ?? '';

  void keepDraft(String threadId, String text) {
    switch (text.isEmpty) {
      case true:
        _drafts.remove(threadId);
      case false:
        _drafts[threadId] = text;
    }
  }

  /// Reads the inbox: what this device holds first, then the server's.
  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    await _loadHeld(userId);
    if (!_remote.allowed) return;
    _status = .loading;
    notifyListeners();
    try {
      final threads = await _service.getThreads();
      if (userId != _userId) return;
      await _local.storeThreads(userId, threads);
      _setThreads(threads);
      _status = .loaded;
    } catch (error, stacktrace) {
      if (userId != _userId) return;
      _status = .failed;
      onError?.call(error, stacktrace: stacktrace);
    }
    notifyListeners();
  }

  /// The inbox as this device holds it, when nothing was read yet.
  Future<void> _loadHeld(String userId) async {
    if (_threads.isNotEmpty) return;
    try {
      final held = await _local.getThreads(userId);
      if (userId == _userId && _threads.isEmpty) _setThreads(held);
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// The app came back to the front, where a push may never have reached it:
  /// the inbox again, once something read it, and each thread on screen, with
  /// what waits there sent.
  Future<void> resume() async {
    await Future.wait([
      if (_status != .idle) load(),
      for (final threadId in _following.keys.toList()) _catchUp(threadId),
    ]);
  }

  Future<void> _catchUp(String threadId) async {
    await pull(threadId);
    await flush(threadId);
  }

  /// The thread of [connectionId]: the one this device holds, else opened on
  /// the server, the first time it is asked for.
  Future<Thread> threadFor(String connectionId) async {
    if (threadOf(connectionId) case final Thread thread) return thread;
    final userId = _userId;
    if (userId == null) throw StateError('no account');
    await _loadHeld(userId);
    if (threadOf(connectionId) case final Thread thread) return thread;
    final thread = await _service.openThread(connectionId);
    if (userId != _userId) throw StateError('signed out');
    await _local.storeThread(userId, thread);
    _setThreads([..._threads.where((each) => each.id != thread.id), thread]);
    notifyListeners();
    return thread;
  }

  /// A screen shows [threadId], until it calls [close]: what this device
  /// holds at once, then what arrived, then sends what waits and marks it
  /// read.
  Future<void> open(String threadId) {
    _following.update(threadId, (count) => count + 1, ifAbsent: () => 1);
    return refresh(threadId);
  }

  /// Reads [threadId] again, as [open] does, for a screen already showing it.
  Future<void> refresh(String threadId) async {
    await _show(threadId);
    await pull(threadId);
    await flush(threadId);
    await markRead(threadId);
  }

  /// Reads what arrived in [threadId] since the newest this device holds, or
  /// the newest page when it holds none. One read at a time per thread; a
  /// call during one gets another after it.
  Future<void> pull(String threadId) => _pulls(threadId, () => _pull(threadId));

  Future<void> _pull(String threadId) async {
    final userId = _userId;
    if (userId == null || !_remote.allowed) return;
    _view(threadId, status: .loading);
    try {
      final stored = await _local.getThreadItems(userId, threadId);
      final placed = stored.where((each) => each.position != null).toList();
      final newest = placed.lastOrNull;
      final known = {for (final each in stored) each.item.id: each};
      final arrived = <StoredItem>[];
      switch (newest?.item.cursor) {
        case final String cursor:
          var since = cursor;
          var next = newest!.position! + 1;
          while (true) {
            final page = await _readSince(threadId, since);
            for (final item in page.items) {
              arrived.add((item: item, position: known[item.id]?.position ?? next++, pending: false));
            }
            if (page.cursor case final String more when page.items.isNotEmpty) {
              since = more;
            } else {
              break;
            }
          }
          // opened again since the app started: one item asks whether more wait
          if (!_older.containsKey(threadId)) {
            _older[threadId] = switch (placed.map((each) => each.item.cursor).nonNulls.firstOrNull) {
              final String oldest => (await _service.getThreadItems(
                threadId,
                before: oldest,
                limit: 1,
              )).items.isNotEmpty,
              null => false,
            };
          }
        case null:
          final page = await _service.getThreadItems(threadId, limit: _page);
          // newest first: the newest takes the highest place
          final items = page.items;
          arrived.addAll([
            for (final (index, item) in items.indexed) (item: item, position: items.length - 1 - index, pending: false),
          ]);
          _older[threadId] = page.cursor != null;
      }
      if (userId != _userId) return;
      if (arrived.isNotEmpty) await _writes(threadId, () => _local.storeThreadItems(userId, arrived));
      await _show(threadId, status: .loaded);
      // a key may wait in the queue with no push to say so: what it opens
      // shows once it is taken
      if (thread(threadId).messages.any((each) => each.opened is Locked)) await _cipher.receive();
    } catch (error, stacktrace) {
      if (userId != _userId) return;
      _view(threadId, status: .failed);
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// A page after [since], or, when the server no longer knows that cursor,
  /// the newest page: what this device holds of it keeps its place.
  Future<({List<ThreadItem> items, String? cursor})> _readSince(String threadId, String since) async {
    try {
      return await _service.getThreadItems(threadId, since: since, limit: _page);
    } on Map catch (refusal) {
      if (refusal case {'code': 'stale_cursor'}) {
        final page = await _service.getThreadItems(threadId, limit: _page);
        return (items: page.items.reversed.toList(), cursor: null);
      }
      rethrow;
    }
  }

  /// Reads a page older than the oldest this device holds.
  Future<void> older(String threadId) async {
    final userId = _userId;
    if (userId == null || !_remote.allowed) return;
    try {
      final stored = await _local.getThreadItems(userId, threadId);
      final oldest = stored.where((each) => each.position != null).firstOrNull;
      final cursor = oldest?.item.cursor;
      if (oldest == null || cursor == null) {
        _older[threadId] = false;
        return await _show(threadId);
      }
      final page = await _service.getThreadItems(threadId, before: cursor, limit: _page);
      if (userId != _userId) return;
      await _writes(
        threadId,
        () => _local.storeThreadItems(userId, [
          for (final (index, item) in page.items.indexed)
            (item: item, position: oldest.position! - 1 - index, pending: false),
        ]),
      );
      _older[threadId] = page.cursor != null;
      await _show(threadId);
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Writes [text] to [threadId]: sealed and kept here at once, then sent.
  /// Throws when it can't be sealed, as with keys not running: nothing is
  /// kept then, and the words stay with the caller.
  Future<void> send(String threadId, String text, {String? subjectType, String? subjectId}) async {
    final userId = _userId;
    if (userId == null) throw StateError('no account');
    final sealed = await _cipher.seal(threadId, text);
    final at = _now().toUtc();
    final item = ThreadItem(
      id: _newId(),
      threadId: threadId,
      senderId: userId,
      kind: 'message',
      subjectType: subjectType,
      subjectId: subjectId,
      content: sealed.content,
      commitment: sealed.commitment,
      tag: '',
      tagKey: '',
      at: at,
      createdAt: at,
    );
    await _local.storeThreadItems(userId, [(item: item, position: null, pending: true)]);
    if (userId != _userId) return;
    _drafts.remove(threadId);
    await _show(threadId);
    await flush(threadId);
  }

  /// Sends what waits in [threadId], oldest first, once its keys reached the
  /// other person's devices. One run at a time per thread; a call during one
  /// gets another after it, so a message written meanwhile goes too.
  Future<void> flush(String threadId) => _flushes(threadId, () => _flush(threadId));

  Future<void> _flush(String threadId) async {
    final userId = _userId;
    final thread = lookup(threadId);
    if (userId == null || thread == null || !_remote.allowed || this.thread(threadId).closed) return;
    if (_retries[threadId]?.isActive ?? false) return;
    final waiting = [
      for (final each in await _local.getThreadItems(userId, threadId))
        if (each.pending) each,
    ];
    if (waiting.isEmpty) return;
    try {
      // the key first: a message nobody can open is no message
      if (thread.otherId case final String otherId) {
        await _cipher.share(threadId, userId: otherId, fingerprint: fingerprintFor?.call(thread));
      }
      for (final (:item, position: _, pending: _) in waiting) {
        final sent = await _service.postThreadItem(
          threadId,
          id: item.id,
          content: item.content,
          commitment: item.commitment,
          at: item.at,
          subjectType: item.subjectType,
          subjectId: item.subjectId,
        );
        if (userId != _userId) return;
        await _writes(threadId, () async {
          final held = (await _local.getThreadItems(userId, threadId)).where((each) => each.item.id == item.id);
          // a read placed it while it travelled: that place and cursor stand
          if (held.firstOrNull case (item: _, position: _, pending: false)) return;
          await _local.storeThreadItems(userId, [(item: sent, position: held.firstOrNull?.position, pending: false)]);
        });
      }
    } on Map catch (refusal, stacktrace) {
      switch (refusal) {
        case {'code': 'thread_closed'}:
          _view(threadId, closed: true);
        case {'code': 'rate_limited'}:
          final wait = switch (refusal['retryAfter']) {
            final num seconds => Duration(seconds: seconds.ceil()),
            _ => const Duration(minutes: 1),
          };
          _retries[threadId]?.cancel();
          _retries[threadId] = Timer(wait, () => unawaited(flush(threadId)));
        default:
          onError?.call(refusal, stacktrace: stacktrace);
      }
    } catch (error, stacktrace) {
      // no network, or keys that couldn't be shared: tried again on the next open
      onError?.call(error, stacktrace: stacktrace);
    }
    if (userId != _userId) return;
    await _show(threadId);
    // what went out places itself, and moves its thread up the inbox
    await Future.wait([pull(threadId), load()]);
  }

  /// Marks [threadId] read to the newest this device holds.
  Future<void> markRead(String threadId) async {
    final userId = _userId;
    if (userId == null || !_remote.allowed) return;
    try {
      final stored = await _local.getThreadItems(userId, threadId);
      final cursor = stored.map((each) => each.item.cursor).nonNulls.lastOrNull;
      final thread = lookup(threadId);
      if (cursor == null || cursor == _marked[threadId] || thread == null) return;
      await _service.markThreadRead(threadId, cursor);
      _marked[threadId] = cursor;
      if (userId != _userId || thread.unread == 0) return;
      final read = Thread(
        id: thread.id,
        connectionId: thread.connectionId,
        otherId: thread.otherId,
        otherName: thread.otherName,
        otherAvatar: thread.otherAvatar,
        unread: 0,
        lastAt: thread.lastAt,
        clearedAt: thread.clearedAt,
        clearedBy: thread.clearedBy,
      );
      await _local.storeThread(userId, read);
      _setThreads([
        for (final each in _threads)
          switch (each.id == threadId) {
            true => read,
            false => each,
          },
      ]);
      notifyListeners();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// A message arrived in [threadId] (`coaching.message`): the inbox again,
  /// and the thread when it is open.
  Future<void> arrived(String threadId) async {
    await load();
    if (_following.containsKey(threadId)) {
      await pull(threadId);
      await markRead(threadId);
    }
  }

  /// The other person deleted [threadId] (`coaching.thread_cleared`): the
  /// inbox again, which says when, and the thread read again.
  Future<void> cleared(String threadId) async {
    await load();
    if (_following.containsKey(threadId)) await pull(threadId);
  }

  /// A screen that called [open] no longer shows [threadId]: once none does,
  /// it is read afresh on the next open.
  void close(String threadId) {
    switch (_following[threadId]) {
      case final int count when count > 1:
        _following[threadId] = count - 1;
      case _:
        _following.remove(threadId);
        _views.remove(threadId);
    }
  }

  Future<void> _keyArrived(String threadId) async {
    final view = _views[threadId];
    if (view == null || !view.messages.any((each) => each.opened is Locked)) return;
    await _show(threadId);
  }

  /// Opens what this device holds of [threadId] and shows it.
  Future<void> _show(String threadId, {CoachingStatus? status}) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final cleared = lookup(threadId)?.clearedAt;
      // all of it opened, what a deletion hid too: a message replayed at a
      // position one of those took is refused
      final stored = await _local.getThreadItems(userId, threadId);
      final opened = await _cipher.open(threadId, [
        for (final (:item, position: _, pending: _) in stored)
          (id: item.id, senderId: item.senderId, content: item.content, commitment: item.commitment),
      ]);
      if (userId != _userId) return;
      final closed = thread(threadId).closed;
      final messages = [
        for (final (index, (:item, position: _, :pending)) in stored.indexed)
          // what came before a deletion is gone for both
          if (cleared == null || pending || item.createdAt.isAfter(cleared))
            Message(
              item: item,
              opened: opened[index],
              mine: item.senderId == userId,
              delivery: switch ((pending, closed)) {
                (false, _) => .sent,
                (true, true) => .closed,
                (true, false) => .waiting,
              },
            ),
      ];
      _view(threadId, messages: messages, status: status);
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  void _view(String threadId, {List<Message>? messages, CoachingStatus? status, bool? closed}) {
    final was = thread(threadId);
    _views[threadId] = MessageThread(
      threadId: threadId,
      messages: messages ?? was.messages,
      status: status ?? was.status,
      hasOlder: _older[threadId] ?? false,
      closed: closed ?? was.closed,
    );
    notifyListeners();
  }

  void _setThreads(Iterable<Thread> threads) {
    _threads
      ..clear()
      ..addAll(threads)
      ..sort((a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)));
  }

  void _forget() {
    for (final timer in _retries.values) {
      timer.cancel();
    }
    _retries.clear();
    _threads.clear();
    _views.clear();
    _following.clear();
    _older.clear();
    _drafts.clear();
    _marked.clear();
    _status = .idle;
  }

  @override
  void onSignOut() {
    _forget();
    _userId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _keys.cancel();
    _forget();
    super.dispose();
  }
}

/// One run at a time per thread. A call during a run gets a run of its own
/// after it, which every call made meanwhile shares: what changed after the
/// running one started is never left out.
class _OneAtATime {
  final _running = <String, Future<void>>{};
  final _queued = <String, Future<void>>{};

  Future<void> call(String threadId, Future<void> Function() run) {
    if (_queued[threadId] case final Future<void> queued) return queued;
    return switch (_running[threadId]) {
      final Future<void> running => _queued[threadId] = running.then((_) {}, onError: (_) {}).then((_) {
        _queued.remove(threadId);
        return _start(threadId, run);
      }),
      null => _start(threadId, run),
    };
  }

  Future<void> _start(String threadId, Future<void> Function() run) {
    late final Future<void> started;
    started = run().whenComplete(() {
      if (identical(_running[threadId], started)) _running.remove(threadId);
    });
    return _running[threadId] = started;
  }
}

/// Calls on one thread's stored items, each after the one before: a read and
/// the write it decides on see nobody else's write between them.
class _InTurn {
  final _last = <String, Future<void>>{};

  Future<void> call(String threadId, Future<void> Function() run) {
    final turn = (_last[threadId] ?? Future<void>.value()).then((_) => run());
    _last[threadId] = turn.then((_) {}, onError: (_) {});
    return turn;
  }
}
