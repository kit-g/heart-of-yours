import 'dart:async';

import 'package:heart/core/env/push.dart';
import 'package:heart_state/heart_state.dart';

/// A [PushClient] standing in for FCM, which a test cannot reach: it logs
/// what the app asked of it, and lets a test push arrivals, taps and
/// pushes that waited in the background.
class FakePushClient implements PushClient {
  final calls = <String>[];
  final newTokens = StreamController<String>.broadcast();
  final arrivals = StreamController<({Push push, String? title})>.broadcast();
  final taps = StreamController<Push>.broadcast();
  final pending = <Push>[];

  /// Holds [createChannels] until completed, when set.
  Completer<void>? channelsMade;

  /// Holds [start] until completed, when set.
  Completer<void>? tokenMade;

  @override
  Stream<String> get tokens => newTokens.stream;

  @override
  Stream<({Push push, String? title})> get arrived => arrivals.stream;

  @override
  Stream<Push> get opened => taps.stream;

  @override
  Future<String?> start() async {
    calls.add('start');
    await tokenMade?.future;
    return 'fcm-1';
  }

  @override
  Future<bool> stop() async {
    calls.add('stop');
    return true;
  }

  @override
  Future<Push?> launchedBy() async => null;

  @override
  Future<List<Push>> takePending() async {
    final taken = [...pending];
    pending.clear();
    return taken;
  }

  @override
  Future<void> createChannels({required String comments, required String messages, required String coaching}) async {
    calls.add('channels $comments $messages $coaching');
    await channelsMade?.future;
  }

  @override
  Future<void> deleteChannels() async => calls.add('delete channels');

  /// Whether [show] posts a system notification, as Android's does; iOS's
  /// cannot.
  bool posts = true;

  /// Whether the OS lets pushes of a kind show, by topic: all of them unless
  /// said.
  final blocked = <String>{};

  @override
  Future<bool> show(Push push, {required String title}) async {
    calls.add('show ${push.topic} $title');
    return posts;
  }

  @override
  Future<bool> allows(Push push) async => !blocked.contains(push.topic);

  @override
  Future<bool> askPermission({Analytics? analytics}) async {
    calls.add('ask');
    return true;
  }
}
