import 'dart:async';
import 'dart:collection';

import 'package:network_utils/network_utils.dart' show NetworkException;

import 'refusals.dart';

/// What a program call's failure says about asking again, for every program
/// call, reads and writes alike: one classifier, so a retry and a refusal
/// never disagree about the same answer.
enum ProgramFailure {
  /// The server broke, or the gateway in front of it was busy (a throttle
  /// reaches the app as a 500 before the server's code runs) or gave up:
  /// asking again may pass.
  passing,

  /// An answer that repeating would only repeat: a rule or key the server
  /// does not take, a cap reached, a row it does not have.
  refused,

  /// Any other answer: an unknown code, or the gateway's own refusal (a 401
  /// is `{message: Unauthorized}`). Asking again the same way gets it again.
  answered,

  /// No answer to read at all: offline, a dropped connection, a body this
  /// side could not parse. Retrying while offline only delays the report.
  unanswered,
}

/// Codes the server refuses with; see [ProgramFailure.refused].
const _refusals = {
  'invalid_rule',
  'invalid_key',
  'invalid_deload',
  'invalid_phase',
  'invalid_test',
  'invalid_target',
  'program_limit',
  'program_history_limit',
  'program_not_found',
  'unknown_program',
  'unknown_exercise',
  'unknown_workout',
  'unknown_action',
  'skip_limit',
};

/// API Gateway's own bodies for a request it could not get answered: a
/// throttled or failed integration, too many requests, a timeout. They carry
/// a `message` and no `code`; their wording is the gateway's, fixed. Only
/// a report's name reads them: their statuses already say to ask again.
const _gatewayBusy = {
  'Internal server error',
  'Too Many Requests',
  'Service Unavailable',
  'Endpoint request timed out',
};

ProgramFailure programFailure(Object? error) {
  return switch (error) {
    ProgramReadFailed(:final error) => programFailure(error),
    // an attempt that ran out of time: its slot is let go, and it is asked
    // again like a busy gateway
    TimeoutException() => .passing,
    // the server broke, or the gateway in front of it was busy or gave up:
    // 408, 425, 429 and 5xx, whatever the body says
    NetworkException(isTransient: true) => .passing,
    NetworkException(isRefusal: true, body: {'code': final String code}) when _refusals.contains(code) => .refused,
    NetworkException() => .answered,
    _ => .unanswered,
  };
}

/// A program read that failed for good: which calls, so the report names
/// them (#660), and groups by them. The message carries the calls and the
/// failure's code, never the body or the program: one issue per call and
/// cause, not one per program.
class ProgramReadFailed implements Exception {
  /// The calls, as the remote service names them: `getProgramBases`.
  final List<String> calls;

  /// What the first of [calls] threw, for a debugger; never in the message.
  final Object error;

  const new(this.calls, this.error);

  /// The failure's name: the server's code, else what kind it was.
  String get code {
    return switch (error) {
      NetworkException(body: {'code': final String code}) => code,
      NetworkException(body: {'message': final String message}) when _gatewayBusy.contains(message) => message,
      TimeoutException() => 'timeout',
      NetworkException() => 'unnamed',
      _ => '${error.runtimeType}',
    };
  }

  @override
  String toString() => 'ProgramReadFailed(${calls.join(', ')}: $code)';
}

/// A read let go unsent, or its answer let go: the account it was for signed
/// out or changed while it waited. Nothing to report.
class ReadDropped implements Exception {
  const new();
}

/// Every program read (#660): a few at a time, each program's once, retried
/// while the failure may pass, and given up quietly for an account that left.
///
/// The gateway's concurrency limit is the account's, across every route, and
/// only these reads are capped here: programs are the one resource a launch
/// reads per row, so they are the burst. A cap for every request belongs in
/// `Api` (heart_api `api.dart`, where `get`/`post` already wrap every call),
/// with this one's lanes; this class would then keep its dedupe and retry
/// and drop its slots.
class ProgramReads {
  /// Whether reads for this account still go out: it is still the one
  /// signed in, and its remote leg is open.
  final bool Function(String uid) _current;

  final _slots = _Bounded(4);

  /// The read of each (kind, account, program) running now, and the one
  /// asked for after it.
  final _running = <(String, String, String), Future<void>>{};
  final _queued = <(String, String, String), Future<void>>{};

  new(this._current);

  /// What waits before each retry; as many retries as waits.
  static const _waits = [Duration(seconds: 1), Duration(seconds: 3)];

  /// One attempt's time: a request that hangs gives its slot back, and
  /// whoever joined its read is answered.
  static const _attempt = Duration(seconds: 15);

  /// [read], the remote call [name] of a program for [uid], in a slot: ahead of the queue
  /// when the user [asked] for it, a pull to refresh or a push they opened.
  /// Asked again after each wait while its failure is [ProgramFailure.passing].
  /// What still fails is thrown as a [ProgramReadFailed] when it was an
  /// answer or a timeout; with no answer at all (offline), as itself, which
  /// the app's reporter knows to drop.
  Future<T> call<T>(String uid, String name, Future<T> Function() read, {bool asked = false, int attempt = 0}) async {
    try {
      return await _slots(() {
        // a backlog outlives a sign-out: what waited is not sent for the
        // account that left
        if (!_current(uid)) throw const ReadDropped();
        return read().timeout(_attempt);
      }, urgent: asked);
    } on ReadDropped {
      rethrow;
    } catch (error, stack) {
      final wait = switch (programFailure(error)) {
        .passing => _waits.elementAtOrNull(attempt),
        .refused || .answered || .unanswered => null,
      };
      if (wait == null) Error.throwWithStackTrace(_named(name, error), stack);
      // the slot is let go while it waits: the burst it was part of drains
      await Future<void>.delayed(wait);
      return call(uid, name, read, asked: asked, attempt: attempt + 1);
    }
  }

  static Object _named(String call, Object error) {
    return switch (error) {
      NetworkException() || TimeoutException() => ProgramReadFailed([call], error),
      _ => error,
    };
  }

  /// [run], the read of [kind] of [programId] for [uid], unless one is
  /// running: a launch's read joins it, and is reported once, by its starter.
  /// One the user [asked] for wants what the server holds now, so it runs
  /// after the running one instead, joined by any asked while it waits.
  /// [run] reports its own failures.
  Future<void> once(String kind, String uid, String programId, Future<void> Function() run, {bool asked = false}) {
    final key = (kind, uid, programId);
    if (_queued[key] case final Future<void> queued) return queued;
    return switch (_running[key]) {
      final Future<void> running when asked => _queued[key] = running.then((_) {
        _queued.remove(key);
        return _start(key, run);
      }),
      final Future<void> running => running,
      null => _start(key, run),
    };
  }

  Future<void> _start((String, String, String) key, Future<void> Function() run) {
    late final Future<void> started;
    // a block: whenComplete awaits a Future its callback returns
    started = run().whenComplete(() {
      if (identical(_running[key], started)) _running.remove(key);
    });
    return _running[key] = started;
  }

  /// The failures of reads run together as one: dropped if any was, else
  /// the named ones as one naming each call, else the first that is not
  /// plainly offline, with its own stack.
  static AsyncError merged(Iterable<AsyncError> failed) {
    if (failed.where((each) => each.error is ReadDropped).firstOrNull case final AsyncError dropped) return dropped;
    final named = [
      for (final each in failed)
        if (each.error case final ProgramReadFailed read) (read, each.stackTrace),
    ];
    if (named.firstOrNull case (final ProgramReadFailed first, final StackTrace stack)) {
      return AsyncError(ProgramReadFailed([for (final (read, _) in named) ...read.calls], first.error), stack);
    }
    return failed.where((each) => programFailure(each.error) != .unanswered).firstOrNull ?? failed.first;
  }
}

/// At most [slots] calls running at once; the rest wait their turn, the
/// urgent ones first, each lane in the order it asked.
class _Bounded {
  final int slots;
  final _urgent = Queue<Completer<void>>();
  final _waiting = Queue<Completer<void>>();
  var _running = 0;

  new(this.slots);

  Future<T> call<T>(Future<T> Function() run, {bool urgent = false}) async {
    if (_running < slots) {
      _running++;
    } else {
      final turn = Completer<void>();
      (urgent ? _urgent : _waiting).add(turn);
      // the slot is handed over by whoever let it go
      await turn.future;
    }
    try {
      return await run();
    } finally {
      final next = _urgent.isNotEmpty ? _urgent : _waiting;
      if (next.isEmpty) {
        _running--;
      } else {
        next.removeFirst().complete();
      }
    }
  }
}
