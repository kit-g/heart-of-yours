import 'package:heart_db/heart_db.dart';
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Charts');

/// Presents [LocalDatabase] as the [LocalChartService] the [Charts] notifier
/// wants, the way [LocalStats] does for stats: the app is the one place that
/// sees `heart_db` and `heart_state` at once.
class LocalCharts implements LocalChartService {
  final LocalDatabase _db;

  const new(this._db);

  /// A row this build cannot read (a kind from a newer one) is left where it
  /// is and out of the dashboard, never a reason to show no dashboard at all.
  @override
  Future<List<DashboardChart>> getCharts(String userId) async {
    final rows = await _db.getChartRows(userId);
    final read = rows.map(_read).nonNulls.toList();
    if (read.length < rows.length) _logger.warning('Skipped ${rows.length - read.length} chart row(s)');
    return read;
  }

  DashboardChart? _read(Map<String, Object?> row) {
    try {
      return DashboardChart.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> saveChart(DashboardChart chart, String userId) {
    return _db.saveChartRow(chart.toRow(), userId);
  }

  @override
  Future<void> updateChart(DashboardChart chart, String userId) async {
    if ((chart.id, chart.toRow()['data']) case (String id, String data)) {
      await _db.updateChartData(id, data, userId);
    }
  }

  @override
  Future<void> deleteChart(String chartId, String userId) {
    return _db.deleteChartPreference(chartId, userId);
  }

  @override
  Future<void> saveChartOrder(Iterable<String> orderedIds, String userId) {
    return _db.saveChartOrder(orderedIds, userId);
  }
}
