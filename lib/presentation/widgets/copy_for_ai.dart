import 'package:flutter/services.dart';
import 'package:heart/core/utils/record_book.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/feature_offer.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/setting_picker.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Copy for AI (#259): a user's own training as text for the assistant of
/// their choice. The sheets that hand it over, and the words it is written
/// in. The text itself is [Transcript]'s (heart_state); this file puts it
/// into the user's language and out through the clipboard or the share sheet.

const _feature = Feature.copyForAi;

/// The workouts the records are looked up for, newest first: one lookup per
/// exercise per workout, and about as many as a transcript's length holds.
const _recordedWorkouts = 40;

/// One finished workout — from its menu in History, the one place the
/// feature is offered. Not on yet, this is the offer: yes goes straight on
/// to the sheet, no earns the one notice.
Future<void> copyWorkoutForAi(BuildContext context, Workout workout) async {
  final preferences = Preferences.of(context);
  if (!preferences.isOn(_feature)) {
    final yes = await _offer(context);
    if (!context.mounted) return;
    preferences.answerOffer(_feature, yes: yes);
    if (!yes) {
      snack(context, L.of(context).featureDeclinedNotice);
      // the snack was the notice: owed once, and now paid
      preferences.acknowledgeDeclineNotice(_feature);
      return;
    }
  }
  return _show(context, _Scope.workout(workout));
}

/// A stretch of finished workouts: the last four weeks, a program's, or a
/// month — from History.
Future<void> copyPeriodForAi(BuildContext context) => _show(context, const _Scope.period());

/// Every session of [exercise] — from its history.
Future<void> copyExerciseForAi(BuildContext context, Exercise exercise) => _show(context, _Scope.exercise(exercise));

/// The one ask, as a sheet over the menu that led to it. Dismissing it is
/// waving it away, which is a no.
Future<bool> _offer(BuildContext context) async {
  final L(:copyForAiOfferTitle, :copyForAiOfferBody) = L.of(context);
  final preferences = Preferences.of(context);
  final answer = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const .fromLTRB(16, 24, 16, 16),
          // the offer is laid out for a list, where it gets unbounded height;
          // in a sheet it would fill the sheet's height without this
          child: Column(
            mainAxisSize: .min,
            children: [
              FeatureOffer(
                key: AppKeys.copyForAiOffer,
                acceptKey: AppKeys.copyForAiAccept,
                declineKey: AppKeys.copyForAiDecline,
                icon: _icon,
                title: copyForAiOfferTitle,
                body: copyForAiOfferBody,
                onAnswer: (yes) => Navigator.of(context).pop(yes),
                onShown: () => preferences.markOffered(_feature),
              ),
            ],
          ),
        ),
      );
    },
  );
  return answer ?? false;
}

const _icon = Icons.auto_awesome_outlined;

Future<void> _show(BuildContext context, _Scope scope) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (_) => _CopySheet(scope: scope, sources: _Sources.of(context)),
  );
}

/// What is being copied.
sealed class _Scope {
  const factory workout(Workout workout) = _WorkoutScope;

  const factory period() = _PeriodScope;

  const factory exercise(Exercise exercise) = _ExerciseScope;
}

final class _WorkoutScope implements _Scope {
  final Workout workout;

  const new(this.workout);
}

final class _PeriodScope implements _Scope {
  const new();
}

final class _ExerciseScope implements _Scope {
  final Exercise exercise;

  const new(this.exercise);
}

/// The stretches a period can be.
enum _Period { weeks, program, month }

/// Everything the sheet reads, taken from the page that opened it: the sheet
/// is a route of its own, over the root navigator.
class _Sources {
  final Preferences preferences;
  final Exercises exercises;
  final List<Workout> history;
  final List<Program> programs;
  final RecordBook? book;

  const new({
    required this.preferences,
    required this.exercises,
    required this.history,
    required this.programs,
    required this.book,
  });

  factory of(BuildContext context) {
    final preferences = Preferences.of(context);
    return _Sources(
      preferences: preferences,
      exercises: Exercises.of(context),
      history: Workouts.of(context).history.toList()..sort((a, b) => b.start.compareTo(a.start)),
      // a program's workouts are a stretch only while Programs is on
      programs: switch (preferences.isOn(.programs)) {
        true => Programs.of(context).all,
        false => const [],
      },
      book: RecordBook.maybeOf(context),
    );
  }

  /// The program the latest workout counted toward, while it is followed.
  Program? get running {
    final following = {
      for (final program in programs)
        if (!program.archived && program.id != null) program.id!: program,
    };
    return history.map((workout) => following[workout.programId]).nonNulls.firstOrNull;
  }
}

class _CopySheet extends StatefulWidget {
  final _Scope scope;
  final _Sources sources;

  const new({required this.scope, required this.sources});

  @override
  State<_CopySheet> createState() => _CopySheetState();
}

class _CopySheetState extends State<_CopySheet> {
  late final _period = ValueNotifier<_Period>(_initialPeriod);
  late final _month = ValueNotifier<DateTime>(_latestMonth);

  /// The text for what is chosen; null while it is being written.
  final _text = ValueNotifier<String?>(null);

  /// Bumped with every choice, so a slow write for an earlier one never
  /// lands over a later one's.
  int _generation = 0;

  _Sources get _sources => widget.sources;

  @override
  void initState() {
    super.initState();
    _period.addListener(_write);
    _month.addListener(_write);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // the copy is the locale's: written here, where L is in reach
    if (_text.value == null) _write();
  }

  @override
  void dispose() {
    _period.dispose();
    _month.dispose();
    _text.dispose();
    super.dispose();
  }

  DateTime get _now => DateTime.now();

  DateTime get _fourWeeksAgo => _now.subtract(const Duration(days: 28));

  _Period get _initialPeriod {
    return switch (_sources.history.firstOrNull) {
      Workout latest when latest.start.isAfter(_fourWeeksAgo) => .weeks,
      _ => .month,
    };
  }

  DateTime _monthOf(DateTime at) => DateTime(at.year, at.month);

  DateTime get _latestMonth => _monthOf((_sources.history.firstOrNull?.start ?? _now).toLocal());

  DateTime get _earliestMonth => _monthOf((_sources.history.lastOrNull?.start ?? _now).toLocal());

  /// The workouts in scope, newest first.
  List<Workout> get _workouts {
    return switch (widget.scope) {
      _WorkoutScope(:final workout) => [workout],
      _ExerciseScope(:final exercise) =>
        _sources.history.where((workout) => workout.any((each) => each.exercise.id == exercise.id)).toList(),
      _PeriodScope() => switch (_period.value) {
        .weeks => _sources.history.where((workout) => workout.start.isAfter(_fourWeeksAgo)).toList(),
        .program => _sources.history.where((workout) => workout.programId == _sources.running?.id).toList(),
        .month => _sources.history.where((workout) => _monthOf(workout.start.toLocal()) == _month.value).toList(),
      },
    };
  }

  Future<void> _write() async {
    final generation = ++_generation;
    // the old text would read as the new choice's while its records load
    _text.value = null;
    final l = L.of(context);
    final workouts = _workouts;
    final records = await _records(workouts.take(_recordedWorkouts), l);
    if (!mounted || generation != _generation) return;
    final transcript = Transcript(
      copy: _Copy(l),
      locale: l.localeName,
      // `late` until the startup read lands: the same guard the export applies
      weightUnit: switch (_sources.preferences.isInitialized) {
        true => _sources.preferences.weightUnit,
        false => .metric,
      },
      distanceUnit: switch (_sources.preferences.isInitialized) {
        true => _sources.preferences.distanceUnit,
        false => .metric,
      },
      exerciseUnits: {
        for (final workout in workouts)
          for (final entry in workout)
            if (_sources.exercises.unitFor(entry.exercise.id) case MeasurementUnit unit) entry.exercise.id: unit,
      },
      programs: {
        for (final program in _sources.programs)
          if (program.id case String id) id: program.name,
      },
      records: records,
    );
    _text.value = switch ((widget.scope, workouts)) {
      (_, []) => '',
      (_WorkoutScope(:final workout), _) => transcript.workout(workout),
      (_ExerciseScope(:final exercise), _) => transcript.exercise(exercise, workouts),
      (_PeriodScope(), _) => transcript.period(workouts),
    };
  }

  /// The records each set holds, named, as of its workout: what the badges
  /// beside it in History say.
  Future<Map<String, List<String>>> _records(Iterable<Workout> workouts, L l) async {
    final userId = _sources.exercises.userId;
    final book = _sources.book;
    if (book == null || userId == null) return const {};
    final marks = await Future.wait(workouts.map((workout) => book.marksOf(workout, userId: userId)));
    return {
      for (final mark in marks)
        for (final MapEntry(key: set, value: kinds) in mark.entries)
          set: [for (final kind in kinds) recordKindName(l, kind)],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);

    return SafeArea(
      child: Padding(
        key: AppKeys.copyForAiSheet,
        padding: .fromLTRB(16, 24, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                const Icon(_icon),
                Expanded(child: Text(l.copyForAi, style: textTheme.titleMedium)),
              ],
            ),
            if (widget.scope case _PeriodScope()) _periodPicker(l),
            ValueListenableBuilder<String?>(
              valueListenable: _text,
              builder: (_, text, _) {
                return Container(
                  constraints: const BoxConstraints(maxHeight: 280, minHeight: 120),
                  decoration: BoxDecoration(
                    border: .all(color: dividerColor, width: .5),
                    borderRadius: const .all(.circular(12)),
                    color: colorScheme.surfaceContainerLow,
                  ),
                  child: switch (text) {
                    null => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    '' => Center(
                      child: Text(
                        l.copyForAiEmpty,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    String text => SingleChildScrollView(
                      key: AppKeys.copyForAiPreview,
                      padding: const .all(12),
                      child: Text(text, style: textTheme.bodySmall),
                    ),
                  },
                );
              },
            ),
            Row(
              spacing: 8,
              crossAxisAlignment: .start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                Expanded(
                  child: Text(
                    l.copyForAiNote,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _text,
              builder: (context, text, _) {
                // nothing to hand over, nothing to press: the line above says why
                if (text == null || text.isEmpty) return const SizedBox(height: 48);
                return Row(
                  mainAxisAlignment: .end,
                  spacing: 8,
                  children: [
                    _ShareButton(text: text),
                    // the share button's 48pt target, so the pair lines up
                    SizedBox(
                      height: 48,
                      child: PrimaryButton.shrunk(
                        key: AppKeys.copyForAiCopy,
                        onPressed: () => _copy(context, text),
                        child: Center(widthFactor: 1, child: Text(l.copyForAiCopy)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodPicker(L l) {
    final running = _sources.running;
    return ListenableBuilder(
      listenable: Listenable.merge([_period, _month]),
      builder: (context, _) {
        final ThemeData(:textTheme) = Theme.of(context);
        final month = _month.value;
        return Column(
          spacing: 8,
          children: [
            Center(
              child: SettingSwitcher<_Period>(
                key: AppKeys.copyForAiPeriod,
                value: _period.value,
                onValueChanged: (period) => _period.value = period ?? _period.value,
                children: {
                  .weeks: _Segment(l.copyForAiLastFourWeeks),
                  // a program's stretch only while one is running
                  if (running != null) .program: _Segment(l.copyForAiProgram),
                  .month: _Segment(l.copyForAiMonth),
                },
              ),
            ),
            switch (_period.value) {
              .month => Row(
                mainAxisAlignment: .center,
                children: [
                  _MonthStep(
                    tooltip: l.copyForAiEarlierMonth,
                    icon: Icons.chevron_left_rounded,
                    onPressed: switch (month.isAfter(_earliestMonth)) {
                      true => () => _month.value = DateTime(month.year, month.month - 1),
                      false => null,
                    },
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM(l.localeName).format(month),
                      textAlign: .center,
                      style: textTheme.titleSmall,
                    ),
                  ),
                  _MonthStep(
                    tooltip: l.copyForAiLaterMonth,
                    icon: Icons.chevron_right_rounded,
                    onPressed: switch (month.isBefore(_monthOf(_now))) {
                      true => () => _month.value = DateTime(month.year, month.month + 1),
                      false => null,
                    },
                  ),
                ],
              ),
              .program => Text(running?.name ?? '', textAlign: .center, style: textTheme.titleSmall),
              .weeks => const SizedBox.shrink(),
            },
          ],
        );
      },
    );
  }

  void _copy(BuildContext context, String text) {
    final messenger = ScaffoldMessenger.of(context);
    final copied = L.of(context).copyForAiCopied;
    Clipboard.setData(ClipboardData(text: text));
    Navigator.of(context).pop();
    messenger.snack(copied);
  }
}

class _Segment extends StatelessWidget {
  final String label;

  const new(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: Text(label, maxLines: 1, overflow: .ellipsis),
    );
  }
}

/// One step through the months. At either end the arrow goes, its place
/// kept so the month's name does not jump.
class _MonthStep extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const new({required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return switch (onPressed) {
      VoidCallback onPressed => IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon)),
      null => const SizedBox.square(dimension: 48),
    };
  }
}

/// Share, through the system sheet: as plain text, so it lands in a chat box
/// rather than as a file attachment.
class _ShareButton extends StatelessWidget {
  final String text;

  const new({required this.text});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: AppKeys.copyForAiShare,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: const Icon(Icons.ios_share_rounded, size: 18),
      label: Text(L.of(context).share),
      onPressed: () {
        // where the iPad's popover points; ignored everywhere else
        final origin = switch (context.findRenderObject()) {
          RenderBox box => box.localToGlobal(Offset.zero) & box.size,
          _ => null,
        };
        SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
      },
    );
  }
}

/// [TranscriptCopy] from the localizations.
class _Copy implements TranscriptCopy {
  final L l;

  const new(this.l);

  @override
  String get workoutIntro => l.aiWorkoutIntro;

  @override
  String periodIntro(int workouts, String range) => l.aiPeriodIntro(workouts, range);

  @override
  String exerciseIntro(String exercise, String shape, int sessions, String range) {
    return l.aiExerciseIntro(exercise, shape, sessions, range);
  }

  @override
  String get howToRead => l.aiHowToRead;

  @override
  String get untitled => l.workout;

  @override
  String program(String name) => l.aiProgram(name);

  @override
  String note(String note) => l.aiNote(note);

  @override
  String energyEstimate(String kcal) => l.aiEnergyEstimate(kcal);

  @override
  String shape(Category category, {required MeasurementUnit weight, required MeasurementUnit distance}) {
    final w = switch (weight) {
      .metric => l.kg,
      .imperial => l.lbs,
    };
    final d = switch (distance) {
      .metric => l.km,
      .imperial => l.milesPlural,
    };
    final short = switch (distance) {
      .metric => l.metresShort,
      .imperial => l.yardsShort,
    };
    return switch (category) {
      .barbell || .dumbbell || .machine => l.aiShapeWeightReps(w),
      .weightedBodyWeight => l.aiShapeAddedWeight(w),
      .assistedBodyWeight => l.aiShapeAssistance(w),
      .repsOnly => l.aiShapeReps,
      .cardio => l.aiShapeDistanceTime(d),
      .duration => l.aiShapeTime,
      .weightedDistance => l.aiShapeWeightDistance(w, short),
      .weightedDuration => l.aiShapeWeightTime(w),
    };
  }

  @override
  String? setType(SetType type) {
    return switch (type) {
      .normal => null,
      .warmup => l.aiSetWarmup,
      .drop => l.aiSetDrop,
      .failure => l.aiSetFailure,
    };
  }

  @override
  String rpe(String value) => l.aiRpe(value);

  @override
  String records(List<String> kinds) => l.aiRecords(kinds.join(', '));

  @override
  String leftOutWorkouts(int workouts, String range) => l.aiLeftOutWorkouts(workouts, range);

  @override
  String leftOutSessions(int sessions, String range) => l.aiLeftOutSessions(sessions, range);
}
