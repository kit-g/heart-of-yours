import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';

/// What waits for a launch's first reads (#676).
void main() {
  test('nothing waits where no launch began', () {
    final opening = OpeningReads();
    var ran = 0;

    opening.after(() => ran++);

    expect(opening.settled, isTrue);
    expect(ran, 1);
  });

  test('a read handed over during a launch runs once, when the opening page has its data', () {
    fakeAsync((async) {
      final opening = OpeningReads()..begin();
      var ran = 0;
      var told = 0;
      opening.addListener(() => told++);

      opening.after(() => ran++);
      expect((opening.settled, ran), (false, 0));

      opening
        ..settle()
        ..settle();
      async.elapse(const Duration(minutes: 1));

      expect((opening.settled, ran, told), (true, 1, 1));
    });
  });

  test('a launch that stalls holds the rest no longer than the limit', () {
    fakeAsync((async) {
      final opening = OpeningReads(limit: const Duration(seconds: 8))..begin();
      var ran = 0;
      opening.after(() => ran++);

      async.elapse(const Duration(seconds: 7));
      expect(ran, 0);
      async.elapse(const Duration(seconds: 1));

      expect((opening.settled, ran), (true, 1));
    });
  });

  test('a second launch in the session, another account, waits afresh', () {
    fakeAsync((async) {
      final opening = OpeningReads()
        ..begin()
        ..settle()
        ..begin();

      expect(opening.settled, isFalse);
      async.elapse(const Duration(seconds: 8));
      expect(opening.settled, isTrue);
    });
  });

  test('a launch that ended cannot let the next one\'s reads go', () {
    fakeAsync((async) {
      final opening = OpeningReads();
      final first = opening.begin();
      final second = opening.begin();

      opening.settle(first);
      expect(opening.settled, isFalse);

      opening.settle(second);
      expect(opening.settled, isTrue);
    });
  });

  test('a session that changed hands lets go of what waited, whichever launch it was', () {
    fakeAsync((async) {
      final opening = OpeningReads()..begin();
      var ran = 0;
      opening.after(() => ran++);

      opening.settle();

      expect((opening.settled, ran), (true, 1));
    });
  });

  test('disposed mid-launch, it tells nobody', () {
    fakeAsync((async) {
      final opening = OpeningReads()..begin();
      var ran = 0;
      opening.after(() => ran++);

      opening.dispose();
      async.elapse(const Duration(minutes: 1));

      expect(ran, 0);
    });
  });
}
