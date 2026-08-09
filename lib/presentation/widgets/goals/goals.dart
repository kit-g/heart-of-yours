/// The goals surface.
///
/// Its own library, and public, for two reasons: it lived inside the profile
/// screen's part library where every class was private, so nothing could
/// construct one in a test — both of the runtime bugs this feature shipped were
/// the kind a widget test catches. And a goal carries more than a row can hold
/// once it has several rungs and deadlines, so the detail surface needs
/// somewhere of its own to live next to the summary.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/chart_dimension.dart';
import 'package:heart/presentation/widgets/date_picker.dart';
import 'package:heart/presentation/widgets/exercise_chart.dart';
import 'package:heart/presentation/widgets/exercises/exercise_picker_dialog.dart';
import 'package:heart/presentation/widgets/feedback_button.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/popping_text.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';

part 'card.dart';
part 'detail.dart';
part 'ladder.dart';
part 'rung.dart';
part 'ladder_bar.dart';
part 'new_goal.dart';
part 'row.dart';
part 'swipe.dart';
part 'text.dart';
part 'thresholds.dart';

/// How far a row travels before the swipe counts as a delete. Matches the
/// exercise set's, so the gesture feels the same wherever it is used.
const _dismissThreshold = .5;

/// Applies an edit to a goal, and says so when the server refuses it.
///
/// A refused edit is rolled back — the server keeps the version it already
/// holds — so without this the rung would simply spring back with nothing said.
/// The messenger is read before the await so nothing touches a stale context.
Future<void> _amend(BuildContext context, Future<void> Function() edit) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await edit();
  } on GoalRejected catch (rejection) {
    messenger.snack(rejection.toString());
  }
}

extension on WorkoutAggregation {
  /// Every workout in the aggregation, not every week.
  ///
  /// What a goal's reading is keyed on. `length` counts weeks, and a session
  /// logged into a week that already exists leaves that unchanged — so a goal
  /// went on showing the value it had before the workout landed.
  int get workoutCount => fold(0, (total, week) => total + week.length);
}

extension on num {
  /// Trims a trailing `.0` — targets are whole far more often than not, and
  /// "100.0 kg" reads like a measurement rather than an intention.
  String trimmed() {
    final fixed = toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}
