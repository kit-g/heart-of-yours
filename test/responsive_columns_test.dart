import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/responsive/columns.dart';

void main() {
  group('columnsFor', () {
    // The width a page gets, not the width of the device it is on. Two-pane
    // panes and browser windows land anywhere in this range.
    test('adds columns rather than stretching them', () {
      const card = 360.0;

      expect(columnsFor(320, maxExtent: card), 1); // small phone
      expect(columnsFor(390, maxExtent: card), 2); // iPhone 16
      expect(columnsFor(470, maxExtent: card), 2); // two-pane master pane
      expect(columnsFor(744, maxExtent: card), 3); // iPad mini portrait
      expect(columnsFor(1133, maxExtent: card), 4); // iPad Pro 11 landscape
      expect(columnsFor(1920, maxExtent: card), 6); // desktop browser
      expect(columnsFor(2560, maxExtent: card), 8); // wide desktop browser
    });

    test('never lets a column exceed maxExtent', () {
      for (var width = 100.0; width <= 3000; width += 7) {
        final columns = columnsFor(width, maxExtent: 360);
        expect(
          width / columns,
          lessThanOrEqualTo(360),
          reason: 'a column at width $width exceeded the max extent',
        );
      }
    });

    test('always yields at least one column', () {
      expect(columnsFor(0, maxExtent: 360), 1);
      expect(columnsFor(-100, maxExtent: 360), 1);
      expect(columnsFor(double.infinity, maxExtent: 360), 1);
      expect(columnsFor(double.nan, maxExtent: 360), 1);
      expect(columnsFor(1, maxExtent: 360), 1);
    });
  });
}
