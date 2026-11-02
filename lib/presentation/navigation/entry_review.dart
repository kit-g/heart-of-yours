import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:heart/core/utils/record_book.dart';
import 'package:heart_state/heart_state.dart';

/// Keeps the database's counts in step with suspicious entries (#428): while
/// the feature is on, a set the user discarded is out of records, charts, the
/// muscle map, the pattern lens and goal progress; off, everything counts, as
/// before the feature existed. Told again whenever the switch or a decision
/// changes, and then the aggregations over those counts are read again, so the
/// profile follows at once.
class EntryReviewPresenter extends StatefulWidget {
  final Widget child;

  /// Tells the database whether the counts leave discarded sets out.
  final ValueChanged<bool> leaveOutDiscarded;

  const new({super.key, required this.child, required this.leaveOutDiscarded});

  @override
  State<EntryReviewPresenter> createState() => _EntryReviewPresenterState();
}

class _EntryReviewPresenterState extends State<EntryReviewPresenter> {
  Preferences? _preferences;
  Anomalies? _anomalies;

  /// What the counts were last told: on or off, and what was discarded. Null
  /// before the first telling.
  (bool, Set<String>)? _told;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    final anomalies = Anomalies.of(context);
    if (!identical(anomalies, _anomalies)) {
      _anomalies?.removeListener(_sync);
      _anomalies = anomalies..addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    _preferences?.removeListener(_sync);
    _anomalies?.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final (preferences, anomalies) = (_preferences, _anomalies);
    if (preferences == null || anomalies == null || !preferences.isInitialized) return;
    final on = preferences.isOn(.entryReview);
    final told = (on, on ? {...anomalies.discardedSets} : const <String>{});
    final previous = _told;
    if (previous != null && previous.$1 == told.$1 && setEquals(previous.$2, told.$2)) return;
    _told = told;
    widget.leaveOutDiscarded(on);
    // the first telling is at launch, before anything has been counted
    if (previous == null) return;
    Stats.of(context).init();
    RecordBook.maybeOf(context)?.forget();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
