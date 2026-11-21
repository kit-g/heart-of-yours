import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/charts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

void main() {
  late MockLocalChartService mockService;
  late Charts sut;
  const userId = 'user-123';

  ExerciseMetricChart exercise(String id) {
    return ExerciseMetricChart(ChartPreference.create(id: id, type: .topSetWeight, data: {'exerciseName': 'bench'}));
  }

  setUp(() {
    mockService = MockLocalChartService();
    sut = Charts(service: mockService)..userId = userId;
  });

  group('Charts Unit Tests', () {
    test('init() loads the charts and notifies listeners', () async {
      final chart = exercise('a');
      when(mockService.getCharts(userId)).thenAnswer((_) async => [chart]);

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.length, 1);
      expect(sut[0], chart);
      expect(probe.notifications, 1);
      verify(mockService.getCharts(userId)).called(1);
    });

    test('addPreference() saves an exercise chart and keeps it under its new id', () async {
      final preference = ChartPreference.exercise('bench', .totalVolume);
      when(mockService.saveChart(any, userId)).thenAnswer((_) async => '7');

      final probe = ListenerProbe()..attach(sut);
      await sut.addPreference(preference);

      final saved = (sut.single as ExerciseMetricChart).preference;
      expect(saved.id, '7');
      expect(saved.type, ChartPreferenceType.totalVolume);
      expect(sut.exerciseCharts.single.id, '7');
      expect(probe.notifications, 1);
    });

    test('an exercise chart goes on once, however many taps race to add it (#626)', () async {
      var saves = 0;
      when(mockService.saveChart(any, userId)).thenAnswer((_) async {
        saves++;
        await Future<void>.delayed(Duration.zero);
        return 'id-$saves';
      });

      final added = await Future.wait([
        sut.addExerciseChart('bench', .totalVolume),
        sut.addExerciseChart('bench', .totalVolume),
      ]);

      expect(added, [true, false]);
      expect(saves, 1);
      expect(sut.exerciseChartOf('bench', .totalVolume)?.id, 'id-1');
      expect(await sut.addExerciseChart('bench', .totalVolume), isFalse, reason: 'already there');
    });

    test('taking an exercise chart off takes every card of it', () async {
      var saved = 0;
      when(mockService.saveChart(any, userId)).thenAnswer((_) async => 'id-${++saved}');
      when(mockService.deleteChart(any, userId)).thenAnswer((_) async {});
      // two, as the profile's New chart dialog can make
      await sut.addPreference(.exercise('bench', .totalVolume));
      await sut.addPreference(.exercise('bench', .totalVolume));

      await sut.removeExerciseChart('bench', .totalVolume);

      expect(sut.exerciseChartOf('bench', .totalVolume), isNull);
      verify(mockService.deleteChart('id-1', userId)).called(1);
      verify(mockService.deleteChart('id-2', userId)).called(1);
    });

    test('add() saves a training chart, which is not an exercise chart', () async {
      when(mockService.saveChart(any, userId)).thenAnswer((_) async => '8');

      await sut.add(const TrainingChart(metric: .sets));

      final TrainingChart(:id, :metric, :period) = sut.single as TrainingChart;
      expect((id, metric, period), ('8', TrainingMetric.sets, ChartPeriod.week));
      expect(sut.exerciseCharts, isEmpty);
    });

    test('update() swaps the chart in place and stores it', () async {
      when(mockService.getCharts(userId)).thenAnswer(
        (_) async => [exercise('a'), const TrainingChart(id: 'b', metric: .volume)],
      );
      await sut.init();

      final changed = (sut[1] as TrainingChart).withPeriod(.month);
      await sut.update(changed);

      expect((sut[1] as TrainingChart).period, ChartPeriod.month);
      verify(mockService.updateChart(changed, userId)).called(1);
    });

    test('removePreference() deletes and removes from state', () async {
      final chart = exercise('pref-id');
      when(mockService.getCharts(userId)).thenAnswer((_) async => [chart]);
      await sut.init();

      final probe = ListenerProbe()..attach(sut);
      await sut.removePreference(chart.preference);

      expect(sut.isEmpty, isTrue);
      expect(probe.notifications, 1);
      verify(mockService.deleteChart('pref-id', userId)).called(1);
    });

    test('remove() deletes a training chart', () async {
      when(mockService.getCharts(userId)).thenAnswer((_) async => [const FrequencyChart(id: 'f', exerciseId: 'x')]);
      await sut.init();

      await sut.remove(sut.first);

      expect(sut.isEmpty, isTrue);
      verify(mockService.deleteChart('f', userId)).called(1);
    });

    test('reorder() moves the chart and persists the new order', () async {
      final a = exercise('a');
      final b = const TrainingChart(id: 'b', metric: .sets);
      final c = const FrequencyChart(id: 'c', exerciseId: 'bench');
      when(mockService.getCharts(userId)).thenAnswer((_) async => [a, b, c]);
      await sut.init();

      final probe = ListenerProbe()..attach(sut);
      // onReorderItem convention: move 'a' (index 0) to the end -> newIndex 2
      await sut.reorder(0, 2);

      expect([sut[0], sut[1], sut[2]], [b, c, a]);
      expect(probe.notifications, 1);

      final captured = verify(mockService.saveChartOrder(captureAny, any)).captured;
      expect((captured.single as List).cast<String>(), ['b', 'c', 'a']);
    });

    test('onSignOut() clears the charts', () async {
      when(mockService.getCharts(userId)).thenAnswer((_) async => [exercise('a')]);
      await sut.init();
      expect(sut.isNotEmpty, isTrue);

      sut.onSignOut();
      expect(sut.isEmpty, isTrue);
    });

    // #719: the log out clears, then awaits the push unregister, and only
    // then is the next uid keyed. A load started for the account that left
    // lands in between, and must neither fill the dashboard nor mark it read.
    test("a load for the session that ended lands on nothing, and the next user's still reads", () async {
      final stale = Completer<List<DashboardChart>>();
      when(mockService.getCharts(userId)).thenAnswer((_) => stale.future);
      final loading = sut.init();

      sut.onSignOut();
      expect(sut.userId, isNull);
      stale.complete([exercise('a')]);
      await loading;

      expect(sut.isEmpty, isTrue);
      expect(sut.initialized, isFalse);

      when(mockService.getCharts('next')).thenAnswer((_) async => [exercise('b')]);
      sut.userId = 'next';
      await sut.init();

      expect(sut.map((each) => each.id), ['b']);
    });
  });

  group('DashboardChart rows', () {
    test('a training chart round-trips its metric and period', () {
      for (final metric in TrainingMetric.values) {
        for (final period in ChartPeriod.values) {
          final row = {...TrainingChart(metric: metric, period: period).toRow(), 'id': 3};
          final read = DashboardChart.fromRow(row) as TrainingChart;
          expect((read.id, read.metric, read.period), ('3', metric, period));
        }
      }
    });

    test('a frequency chart is keyed by exerciseName, as an exercise chart is', () {
      final row = const FrequencyChart(exerciseId: 'bench').toRow();
      expect(jsonDecode(row['data'] as String), {'exerciseName': 'bench'});

      final read = DashboardChart.fromRow({...row, 'id': 4}) as FrequencyChart;
      expect((read.id, read.exerciseId), ('4', 'bench'));
    });

    test('an exercise metric reads as heart_models has it', () {
      final read = DashboardChart.fromRow({
        'id': 1,
        'type': 'totalReps',
        'data': jsonEncode({'exerciseName': 'bench'}),
      });
      expect(read, isA<ExerciseMetricChart>());
      expect((read as ExerciseMetricChart).preference.type, ChartPreferenceType.totalReps);
    });

    test('a kind this build does not know throws, for the reader to skip', () {
      expect(() => DashboardChart.fromRow({'id': 1, 'type': 'fromTheFuture', 'data': '{}'}), throwsArgumentError);
      expect(
        () => DashboardChart.fromRow({
          'id': 1,
          'type': 'trainingSets',
          'data': jsonEncode({'period': 'decade'}),
        }),
        throwsA(anything),
      );
    });
  });

  group('Charts Widget Tests', () {
    testWidgets('Provider helpers work correctly', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<Charts>.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final ofInstance = Charts.of(context);
              final watchInstance = Charts.watch(context);

              expect(identical(ofInstance, sut), isTrue);
              expect(identical(watchInstance, sut), isTrue);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
