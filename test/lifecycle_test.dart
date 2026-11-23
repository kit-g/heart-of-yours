import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/lifecycle.dart';

void main() {
  testWidgets('coming back is a return, and what the system lays over the app is not', (tester) async {
    var now = DateTime(2026, 11, 22, 20);
    await withClock(Clock(() => now), () async {
      var returns = 0;
      var resumes = 0;
      final listener = AppReturns(() => returns++, onResume: () => resumes++);
      addTearDown(listener.dispose);
      void through(List<AppLifecycleState> states) => states.forEach(tester.binding.handleAppLifecycleStateChanged);

      // a photo picker, a permission, Control Centre
      through([.inactive, .resumed]);
      expect((resumes, returns), (1, 0));

      // another app, or the lock screen, however short
      through([.inactive, .hidden, .paused, .hidden, .inactive, .resumed]);
      expect((resumes, returns), (2, 1));

      // again only over the app
      through([.inactive, .resumed]);
      expect((resumes, returns), (3, 1));

      // a tablet's other window, for a while
      through([.inactive]);
      now = now.add(const Duration(minutes: 1));
      through([.resumed]);
      expect((resumes, returns), (4, 2));
    });
  });
}
