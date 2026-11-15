import 'package:flutter/foundation.dart';

/// Where one message sits among its neighbours: whether a new day starts at
/// it, and whether it starts a run of one person's messages, which are drawn
/// close together as one turn of the conversation.
typedef MessagePlace = ({bool newDay, bool firstOfRun});

/// A run breaks where the writer changes, where a day ends, and where more
/// than [pause] passes between two messages.
@immutable
class MessageRuns {
  final Duration pause;

  const new({this.pause = const Duration(minutes: 5)});

  /// The place of each of [messages], oldest first, by the writer's own clock
  /// shown in local time.
  List<MessagePlace> of(List<({DateTime at, bool mine})> messages) {
    return [
      for (final (index, message) in messages.indexed)
        (
          newDay: switch (index) {
            0 => true,
            _ => !_sameDay(messages[index - 1].at, message.at),
          },
          firstOfRun: switch (index) {
            0 => true,
            _ => _breaks(messages[index - 1], message),
          },
        ),
    ];
  }

  bool _breaks(({DateTime at, bool mine}) before, ({DateTime at, bool mine}) after) {
    return before.mine != after.mine || !_sameDay(before.at, after.at) || after.at.difference(before.at).abs() > pause;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final (x, y) = (a.toLocal(), b.toLocal());
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
