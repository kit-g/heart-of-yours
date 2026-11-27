import 'package:heart/core/utils/records.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/menu.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// What a suspicious entry (#428) is called and why it was flagged — copy, so
/// here rather than on the model (`docs/style.md`). A reason this build does
/// not know, one a newer server added, reads as something that looks off.
extension AnomalyCopy on Anomaly {
  /// A word or two for the mark beside the entry.
  String short(L l) {
    return switch (reason) {
      AnomalyReason.durationLeftRunning => l.anomalyLeftRunning,
      AnomalyReason.outlierWeight => l.anomalyOutlierWeight,
      AnomalyReason.implausibleReps => l.anomalyImplausibleReps,
      AnomalyReason.swapSuspected => l.anomalySwapSuspected,
      _ => l.anomalyUnknown,
    };
  }

  /// A sentence on what was entered and why it reads as a slip, in the units
  /// the user reads [exercise] in.
  String explained(L l, Preferences prefs, {MeasurementUnit? unit}) {
    final formats = RecordFormats(l: l, prefs: prefs, unit: unit);
    return switch ((reason, observed, typical)) {
      (AnomalyReason.durationLeftRunning, {'seconds': final num seconds}, _) => l.anomalyLeftRunningExplained(
        _hours(l, Duration(seconds: seconds.round())),
      ),
      (AnomalyReason.outlierWeight, {'weight': final num weight}, final num typical) => l.anomalyOutlierWeightExplained(
        formats.weight(weight),
        formats.weight(typical),
      ),
      (AnomalyReason.implausibleReps, {'reps': final num reps}, _) => l.anomalyImplausibleRepsExplained(
        '${reps.round()}',
      ),
      (AnomalyReason.swapSuspected, {'weight': final num weight, 'reps': final num reps}, _) =>
        l.anomalySwapSuspectedExplained(formats.weight(weight), '${reps.round()}'),
      _ => l.anomalyUnknownExplained,
    };
  }
}

/// A long workout as hours and minutes, the way its card says it: "7 h 12 min".
String _hours(L l, Duration elapsed) {
  final minutes = elapsed.inMinutes % 60;
  return [
    if (elapsed.inHours > 0) '${elapsed.inHours} ${l.h}',
    if (minutes > 0 || elapsed.inHours == 0) '$minutes ${l.min}',
  ].join(' ');
}

/// The anomalies a past workout's page marks (#428), under [child]: its sets'
/// and its duration's, while the feature is on. Nothing outside such a page
/// is marked — the workout in progress and a template's editor carry no
/// scope — and nothing at all while the feature is off.
///
/// A kept entry carries no mark: the user said it stands, and a mark on it
/// would ask the question again.
class EntryReviewScope extends InheritedWidget {
  final String workoutId;

  const new({super.key, required this.workoutId, required super.child});

  static Anomaly? _shown(BuildContext context, Anomaly? Function(Anomalies) pick) {
    if (context.dependOnInheritedWidgetOfExactType<EntryReviewScope>() == null) return null;
    if (!Preferences.watch(context).isOn(.entryReview)) return null;
    return switch (Provider.of<Anomalies?>(context)) {
      final Anomalies anomalies => switch (pick(anomalies)) {
        final Anomaly anomaly when anomaly.status != .valid => anomaly,
        _ => null,
      },
      null => null,
    };
  }

  /// The mark [setId] carries, if any.
  static Anomaly? ofSet(BuildContext context, String setId) => _shown(context, (all) => all.ofSet(setId));

  /// The mark the workout's duration carries, if any.
  static Anomaly? ofDuration(BuildContext context) {
    final workoutId = context.dependOnInheritedWidgetOfExactType<EntryReviewScope>()?.workoutId;
    if (workoutId == null) return null;
    return _shown(context, (all) => all.durationOf(workoutId));
  }

  @override
  bool updateShouldNotify(EntryReviewScope old) => old.workoutId != workoutId;
}

/// The mark beside a flagged entry: a quiet outlined pill with the reason, or
/// "Left out" once the user discarded it. Tapping it opens the decision.
class AnomalyMark extends StatefulWidget {
  final Anomaly anomaly;

  const new({super.key, required this.anomaly});

  @override
  State<AnomalyMark> createState() => _AnomalyMarkState();
}

class _AnomalyMarkState extends State<AnomalyMark> {
  final _anchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    final anomaly = widget.anomaly;
    final (icon, label) = switch (anomaly.status) {
      .invalid => (Icons.remove_circle_outline_rounded, l.anomalyLeftOut),
      .pending || .valid => (Icons.flag_outlined, anomaly.short(l)),
    };
    final color = colorScheme.onSurfaceVariant;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: l.anomalyMarkLabel(label),
        onTap: _open,
        child: InkWell(
          key: _anchor,
          onTap: _open,
          borderRadius: const .all(.circular(10)),
          // a pill of 11pt type, in a target a finger finds
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const .symmetric(vertical: 4),
              child: Align(
                widthFactor: 1,
                child: DecoratedBox(
                  key: AppKeys.anomalyMark(anomaly.id),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: const .all(.circular(10)),
                  ),
                  child: Padding(
                    padding: const .symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: .min,
                      spacing: 4,
                      children: [
                        Icon(icon, size: 12, color: color),
                        Text(label, style: textTheme.labelSmall?.copyWith(color: color)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open() => showEntryDecision(context, widget.anomaly, position: _anchor.position());
}

/// The popup's one width: wide enough for its explanation to wrap as a short
/// paragraph, and a multiple of 56, the step a popup rounds its width up to.
const _decisionWidth = 280.0;

/// What the user can make of [anomaly] (#428), in the popup the app's option
/// menus use: why it was flagged, then keep it or leave it out — whichever it
/// is not already — and, with [onOpenWorkout], the workout it is in, where
/// the entry itself can be changed. A decision can be changed later, so none
/// of this asks for confirmation.
Future<void> showEntryDecision(
  BuildContext context,
  Anomaly anomaly, {
  RelativeRect? position,
  VoidCallback? onOpenWorkout,
}) async {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final l = L.of(context);
  final prefs = Preferences.of(context);
  final unit = switch (anomaly.exerciseId) {
    final String id => Exercises.of(context).unitFor(id),
    null => null,
  };
  final anomalies = Anomalies.of(context);

  PopupMenuItem<_Decision> item(_Decision value, IconData icon, String title, String subtitle) {
    return PopupMenuItem<_Decision>(
      key: AppKeys.anomalyDecision(value.name),
      value: value,
      child: SizedBox(
        width: _decisionWidth,
        child: Row(
          spacing: 12,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final picked = await showMenu<_Decision>(
    context: context,
    position: position ?? const RelativeRect.fromLTRB(16, 120, 16, 0),
    items: [
      PopupMenuItem<_Decision>(
        enabled: false,
        child: SizedBox(
          width: _decisionWidth,
          child: Text(
            anomaly.explained(l, prefs, unit: unit),
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          ),
        ),
      ),
      if (anomaly.status != .valid) item(.keep, Icons.check_rounded, l.anomalyKeep, l.anomalyKeepSubtitle),
      if (anomaly.status != .invalid)
        item(.leaveOut, Icons.remove_circle_outline_rounded, l.anomalyLeaveOut, l.anomalyLeaveOutSubtitle),
      if (onOpenWorkout != null)
        item(.open, Icons.open_in_new_rounded, l.anomalyOpenWorkout, l.anomalyOpenWorkoutSubtitle),
    ],
  );

  switch (picked) {
    case .keep:
      await anomalies.resolve(anomaly, .valid);
    case .leaveOut:
      await anomalies.resolve(anomaly, .invalid);
    case .open:
      onOpenWorkout?.call();
    case null:
      return;
  }
}

enum _Decision { keep, leaveOut, open }
