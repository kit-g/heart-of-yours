import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

extension SkipReasonCopy on SkipReason {
  String label(L l) {
    return switch (this) {
      .tired => l.skipReasonTired,
      .sore => l.skipReasonSore,
      .sick => l.skipReasonSick,
      .busy => l.skipReasonBusy,
      .justNo => l.skipReasonJustNo,
    };
  }
}

/// What follows a skip already recorded (#312): [title] saying so, the one
/// optional tap for a reason, and Undo. Dismissing it is the answer "no
/// reason": nothing is asked again, and nothing is required.
Future<void> showSkipSheet(BuildContext context, TrainingSkip skip, {required String title}) {
  final programs = Programs.of(context);
  final analytics = Analytics.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (context) => _SkipSheet(skip: skip, title: title, programs: programs, analytics: analytics),
  );
}

class _SkipSheet extends StatelessWidget {
  final TrainingSkip skip;
  final String title;

  /// Passed in: the sheet is a route of its own.
  final Programs programs;
  final Analytics analytics;

  const new({required this.skip, required this.title, required this.programs, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final navigator = Navigator.of(context);

    return SafeArea(
      child: Padding(
        key: AppKeys.skipSheet,
        padding: const .fromLTRB(16, 24, 16, 8),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: 12,
          children: [
            Text(title, style: textTheme.titleMedium),
            Text(copy.skipWhy, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in SkipReason.values)
                  ActionChip(
                    key: AppKeys.skipReason(reason.value),
                    label: Text(reason.label(copy), style: textTheme.bodyMedium),
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    onPressed: () {
                      analytics.skipReasonGiven(reason: reason);
                      programs.giveReason(skip, reason);
                      navigator.pop();
                    },
                  ),
              ],
            ),
            Align(
              alignment: .centerRight,
              child: TextButton(
                key: AppKeys.skipUndo,
                onPressed: () {
                  analytics.programUnskipped();
                  programs.unskip(skip);
                  navigator.pop();
                },
                child: Text(copy.undo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
