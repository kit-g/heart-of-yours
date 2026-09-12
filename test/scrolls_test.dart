// The scrolling half of the navbar back-action doctrine: tapping the nav button
// for the stack you are already on takes that stack's list to the top.
//
// What is pinned here is the property the app frame leans on rather than the
// frame itself. `_customCallbacks` calls `scrollEditableWorkoutToTop()`
// unconditionally now — it used to ask `matchedLocation.startsWith('/history/')`
// whether the workout editor was open, which broke the moment that route moved.
// Dropping the question is only safe because a controller with nothing attached
// scrolls nothing. If that ever stops being true, every History tap throws.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/scrolls.dart';

void main() {
  late Scrolls scrolls;

  setUp(() => scrolls = Scrolls());

  /// Mounts a list driven by [controller], tall enough to scroll.
  Future<void> pumpList(WidgetTester tester, ScrollController controller) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          controller: controller,
          itemCount: 200,
          itemBuilder: (_, index) => SizedBox(height: 60, child: Text('row $index')),
        ),
      ),
    );
    await tester.pump();
  }

  /// Starts [scroll] and pumps until it lands.
  ///
  /// Never `await` one of these before pumping: the animation only advances on
  /// a frame, so awaiting it first deadlocks the test.
  Future<void> run(WidgetTester tester, Future<void> Function() scroll) async {
    final done = scroll();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await done;
  }

  group('a controller with nothing attached', () {
    test('scrolls nothing, and does not throw', () async {
      // Nothing is mounted, so no position exists. This is the workout editor
      // while it is closed, which History now asks to scroll on every tap.
      expect(scrolls.editWorkoutScrollController.hasClients, isFalse);

      await expectLater(scrolls.scrollEditableWorkoutToTop(), completes);
      await expectLater(scrolls.resetHistoryStack(), completes);
      await expectLater(scrolls.resetExerciseStack(), completes);
      await expectLater(scrolls.scrollProfileToTop(), completes);
      await expectLater(scrolls.scrollWorkoutToTop(), completes);
    });
  });

  group('an attached controller', () {
    testWidgets('resetExerciseStack takes the list back to the top', (tester) async {
      await pumpList(tester, scrolls.exercisesScrollController);

      scrolls.exercisesScrollController.jumpTo(900);
      await tester.pump();
      expect(scrolls.exercisesScrollController.offset, 900);

      await run(tester, scrolls.resetExerciseStack);

      expect(scrolls.exercisesScrollController.offset, 0);
    });

    testWidgets('resetHistoryStack does the same for history', (tester) async {
      await pumpList(tester, scrolls.historyScrollController);

      scrolls.historyScrollController.jumpTo(600);
      await tester.pump();

      await run(tester, scrolls.resetHistoryStack);

      expect(scrolls.historyScrollController.offset, 0);
    });

    testWidgets('a list already at the top stays there', (tester) async {
      await pumpList(tester, scrolls.exercisesScrollController);
      expect(scrolls.exercisesScrollController.offset, 0);

      await run(tester, scrolls.resetExerciseStack);

      expect(scrolls.exercisesScrollController.offset, 0);
    });

    testWidgets('scrollProfileToBottom is the profile\'s other direction', (tester) async {
      await pumpList(tester, scrolls.profileScrollController);

      await run(tester, scrolls.scrollProfileToBottom);

      final position = scrolls.profileScrollController.position;
      expect(scrolls.profileScrollController.offset, position.maxScrollExtent);
    });
  });
}
