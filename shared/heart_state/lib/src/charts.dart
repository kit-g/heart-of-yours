import 'dart:convert';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// What a training chart totals, across every exercise (#137). [value] is the
/// kind as stored beside heart_models' [ChartPreferenceType]s.
enum TrainingMetric {
  /// Weight times reps over every working set.
  volume('trainingVolume'),

  /// Working sets.
  sets('trainingSets'),

  /// How long a workout ran, less its pauses: the period's average.
  duration('trainingDuration');

  final String value;

  new(this.value);
}

/// How much time one point of a training chart covers.
enum ChartPeriod {
  week('week'),
  month('month');

  final String value;

  new(this.value);
}

/// One card on the profile dashboard.
///
/// An exercise's metric is heart_models' [ChartPreference], which the shared
/// interface owns. The training-wide kinds (#137) are the app's own: charts are
/// stored on the device only (heart-api#271 parks their sync), so nothing past
/// this app ever reads them. They share the one table, order and removal with
/// the exercise charts, and a build that predates a kind skips its row rather
/// than failing the dashboard (see `_readable` in heart_db).
sealed class DashboardChart {
  /// The stored row's id; null until the chart is saved.
  String? get id;

  /// The row's `type` and `data`, as stored.
  Map<String, Object?> toRow();

  /// This chart under the id the store gave it.
  DashboardChart withId(String id);

  /// Throws on a kind this build does not know, as [ChartPreference.fromRow]
  /// does: the caller skips such a row.
  factory fromRow(Map row) {
    final id = row['id']?.toString();
    final data = switch (row['data']) {
      String raw => jsonDecode(raw),
      Map m => m,
      _ => null,
    };
    final training = TrainingMetric.values.where((each) => each.value == row['type']).firstOrNull;
    return switch ((row['type'], training, data)) {
      (_, TrainingMetric metric, {'period': String period}) => TrainingChart(
        id: id,
        metric: metric,
        period: ChartPeriod.values.firstWhere((each) => each.value == period),
      ),
      (FrequencyChart.kind, null, {'exerciseName': String exerciseId}) => FrequencyChart(
        id: id,
        exerciseId: exerciseId,
      ),
      _ => ExerciseMetricChart(ChartPreference.fromRow(row)),
    };
  }
}

/// One exercise's metric, as heart_models defines it.
final class ExerciseMetricChart implements DashboardChart {
  final ChartPreference preference;

  const new(this.preference);

  @override
  String? get id => preference.id;

  @override
  Map<String, Object?> toRow() => preference.toRow();

  @override
  ExerciseMetricChart withId(String id) => ExerciseMetricChart(preference.copyWith(id: id));
}

/// A total across every exercise, per week or per month (#137).
final class TrainingChart implements DashboardChart {
  @override
  final String? id;
  final TrainingMetric metric;
  final ChartPeriod period;

  const new({this.id, required this.metric, this.period = .week});

  @override
  Map<String, Object?> toRow() {
    return {
      'id': id,
      'type': metric.value,
      'data': jsonEncode({'period': period.value}),
    };
  }

  @override
  TrainingChart withId(String id) => TrainingChart(id: id, metric: metric, period: period);

  TrainingChart withPeriod(ChartPeriod period) => TrainingChart(id: id, metric: metric, period: period);
}

/// The days one exercise was trained on, as a heatmap (#137).
final class FrequencyChart implements DashboardChart {
  /// The kind as stored.
  static const kind = 'exerciseFrequency';

  @override
  final String? id;
  final String exerciseId;

  const new({this.id, required this.exerciseId});

  @override
  Map<String, Object?> toRow() {
    return {
      'id': id,
      'type': kind,
      // keyed as an exercise chart's is, so moving an exercise's history
      // re-keys this one with them (heart_db's `moveHistory`)
      'data': jsonEncode({'exerciseName': exerciseId}),
    };
  }

  @override
  FrequencyChart withId(String id) => FrequencyChart(id: id, exerciseId: exerciseId);
}

/// Where [Charts] keeps the dashboard.
///
/// The app's own interface rather than heart_models' [ChartPreferenceService],
/// which can only speak of exercise metrics: the same arrangement as
/// `LocalStatsService`, joined to the database in the app.
abstract interface class LocalChartService {
  /// Every chart of [userId]'s this build can read, in the dashboard's order.
  Future<List<DashboardChart>> getCharts(String userId);

  /// Stores [chart] as the newest and returns the id it was given.
  Future<String> saveChart(DashboardChart chart, String userId);

  /// Stores [chart]'s new settings in its place.
  Future<void> updateChart(DashboardChart chart, String userId);

  Future<void> deleteChart(String chartId, String userId);

  Future<void> saveChartOrder(Iterable<String> orderedIds, String userId);
}

class Charts with ChangeNotifier, Iterable<DashboardChart> implements SignOutStateSentry {
  final _charts = <DashboardChart>[];
  final LocalChartService _service;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  String? userId;
  bool initialized = false;
  Future<void>? _loading;

  new({
    required this._service,
    this.onError,
  });

  @override
  void onSignOut() {
    _charts.clear();
    initialized = false;
    _loading = null;
  }

  @override
  Iterator<DashboardChart> get iterator => _charts.iterator;

  DashboardChart operator [](int index) {
    return _charts[index];
  }

  /// The exercise metrics among the charts.
  Iterable<ChartPreference> get exerciseCharts {
    return _charts.whereType<ExerciseMetricChart>().map((each) => each.preference);
  }

  static Charts of(BuildContext context) {
    return Provider.of<Charts>(context, listen: false);
  }

  static Charts watch(BuildContext context) {
    return Provider.of<Charts>(context, listen: true);
  }

  Future<void> init() {
    // idempotent: a completed init is a no-op, and concurrent callers share the
    // single in-flight load, so preferences are never appended twice
    return switch ((initialized, userId)) {
      (true, _) => Future.value(),
      (false, String id) => _loading ??= _load(id).whenComplete(() => _loading = null),
      (false, null) => Future.value(),
    };
  }

  /// Reads the preferences again, past a completed [init]: the mirror changed
  /// under them (an exercise's history moved, #338).
  Future<void> reload() {
    return switch (userId) {
      String id => _loading ??= _load(id).whenComplete(() => _loading = null),
      null => Future.value(),
    };
  }

  /// A failure is reported and leaves [initialized] false, so the next [init]
  /// tries again; nobody awaits it to the point of handling what it throws.
  Future<void> _load(String id) async {
    try {
      final charts = await _service.getCharts(id);
      _charts
        ..clear()
        ..addAll(charts);
      initialized = true;
      notifyListeners();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  Future<void> add(DashboardChart chart) async {
    if (userId case String id) {
      final saved = await _service.saveChart(chart, id);
      _charts.add(chart.withId(saved));
      notifyListeners();
    }
  }

  Future<void> addPreference(ChartPreference preference) => add(ExerciseMetricChart(preference));

  /// Puts [chart] in the place of the stored chart with its id.
  Future<void> update(DashboardChart chart) async {
    final index = _charts.indexWhere((each) => each.id == chart.id);
    if ((userId, index) case (String id, >= 0)) {
      _charts[index] = chart;
      notifyListeners();
      await _service.updateChart(chart, id);
    }
  }

  Future<void> remove(DashboardChart chart) => _removeId(chart.id);

  Future<void> removePreference(ChartPreference preference) => _removeId(preference.id);

  Future<void> _removeId(String? chartId) async {
    if ((userId, chartId) case (String id, String chartId)) {
      await _service.deleteChart(chartId, id);
      _charts.removeWhere((each) => each.id == chartId);
      notifyListeners();
    }
  }

  /// Moves the chart at [oldIndex] to [newIndex] and persists the new order.
  /// [newIndex] is already adjusted for the removed item (the `onReorderItem`
  /// convention).
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (userId case String id) {
      final moved = _charts.removeAt(oldIndex);
      _charts.insert(newIndex, moved);
      notifyListeners();
      await _service.saveChartOrder(_charts.map((each) => each.id).nonNulls.toList(), id);
    }
  }
}
