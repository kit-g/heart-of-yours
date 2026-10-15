import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';

void main() {
  // Wednesday 2026-10-14, mid-afternoon
  final wednesday = DateTime(2026, 10, 14, 15, 30);

  group('weekStart', () {
    test('goes back to the chosen first day, at midnight', () {
      expect(weekOf(wednesday, firstWeekday: DateTime.monday), DateTime(2026, 10, 12));
      expect(weekOf(wednesday, firstWeekday: DateTime.sunday), DateTime(2026, 10, 11));
      expect(weekOf(wednesday, firstWeekday: DateTime.saturday), DateTime(2026, 10, 10));
    });

    test('the first day itself starts its own week', () {
      expect(weekOf(DateTime(2026, 10, 11, 23, 59), firstWeekday: DateTime.sunday), DateTime(2026, 10, 11));
      expect(weekOf(DateTime(2026, 10, 11, 23, 59), firstWeekday: DateTime.monday), DateTime(2026, 10, 5));
    });

    test('crosses a month and a year', () {
      expect(weekOf(DateTime(2027, 1, 1), firstWeekday: DateTime.monday), DateTime(2026, 12, 28));
    });
  });

  group('weekOf', () {
    test('is seven calendar days, half open', () {
      expect(weekRange(wednesday, firstWeekday: DateTime.sunday), (DateTime(2026, 10, 11), DateTime(2026, 10, 18)));
    });

    test('ends at midnight across a DST change', () {
      // Europe and North America leave summer time in the week of 2026-11-01
      final (_, end) = weekRange(DateTime(2026, 10, 28), firstWeekday: DateTime.monday);
      expect((end.hour, end.minute), (0, 0));
      expect(end, DateTime(2026, 11, 2));
    });
  });
}
