import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/src/charts.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

void main() {
  late MockChartPreferenceService mockService;
  late Charts sut;
  const userId = 'user-123';

  setUp(() {
    mockService = MockChartPreferenceService();
    sut = Charts(service: mockService)..userId = userId;
  });

  group('Charts Unit Tests', () {
    test('init() loads preferences and notifies listeners', () async {
      final pref = MockChartPreference();
      when(mockService.getPreferences(userId)).thenAnswer((_) async => [pref]);

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.length, 1);
      expect(sut[0], pref);
      expect(probe.notifications, 1);
      verify(mockService.getPreferences(userId)).called(1);
    });

    test('addPreference() saves and adds to state', () async {
      final newPref = MockChartPreference();
      final savedPref = MockChartPreference();
      when(mockService.saveChartPreference(newPref, userId)).thenAnswer((_) async => savedPref);

      final probe = ListenerProbe()..attach(sut);
      await sut.addPreference(newPref);

      expect(sut.contains(savedPref), isTrue);
      expect(probe.notifications, 1);
      verify(mockService.saveChartPreference(newPref, userId)).called(1);
    });

    test('removePreference() deletes and removes from state', () async {
      final pref = MockChartPreference();
      when(pref.id).thenReturn('pref-id');

      // Manually inject pref into state for testing removal
      when(mockService.getPreferences(userId)).thenAnswer((_) async => [pref]);
      await sut.init();

      when(mockService.deleteChartPreference('pref-id', userId)).thenAnswer((_) async {});

      final probe = ListenerProbe()..attach(sut);
      await sut.removePreference(pref);

      expect(sut.isEmpty, isTrue);
      expect(probe.notifications, 1);
      verify(mockService.deleteChartPreference('pref-id', userId)).called(1);
    });

    test('reorder() moves the chart and persists the new order', () async {
      final a = MockChartPreference();
      final b = MockChartPreference();
      final c = MockChartPreference();
      when(a.id).thenReturn('a');
      when(b.id).thenReturn('b');
      when(c.id).thenReturn('c');
      when(mockService.getPreferences(userId)).thenAnswer((_) async => [a, b, c]);
      when(mockService.saveChartOrder(any, any)).thenAnswer((_) async {});
      await sut.init();

      final probe = ListenerProbe()..attach(sut);
      // onReorderItem convention: move 'a' (index 0) to the end -> newIndex 2
      await sut.reorder(0, 2);

      expect([sut[0], sut[1], sut[2]], [b, c, a]);
      expect(probe.notifications, 1);

      final captured = verify(mockService.saveChartOrder(captureAny, any)).captured;
      expect((captured.single as List).cast<String>(), ['b', 'c', 'a']);
    });

    test('onSignOut() clears preferences', () async {
      final pref = MockChartPreference();
      when(mockService.getPreferences(userId)).thenAnswer((_) async => [pref]);
      await sut.init();
      expect(sut.isNotEmpty, isTrue);

      sut.onSignOut();
      expect(sut.isEmpty, isTrue);
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
