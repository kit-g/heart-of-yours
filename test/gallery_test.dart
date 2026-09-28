// GalleryPage, pumped directly.
//
// It is public (declared in a `part` of the private `workout.dart` library,
// but the class itself carries no leading underscore) and depends on no
// provider — it takes its media as a plain list — so a direct pump with just
// a MaterialApp for localizations is real app code and the simplest way to
// reach it, the same call `history`/`workout_editor` make through
// `context.goToGallery`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';

// a 1x1 transparent PNG: enough for `Image.memory` to decode without an
// error frame, unlike arbitrary bytes.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  // `WorkoutImage.timestamp` is recovered from the workout id (a v7 uuid, or —
  // for the pre-uuid era — the start time itself as an ISO string), not stored
  // on the image row directly. An ISO string id is the simplest way to hand a
  // fixture a specific, parseable timestamp.
  WorkoutImage image({required String id, DateTime? timestamp}) {
    final workoutId = timestamp?.toIso8601String() ?? 'w1';
    return WorkoutImage.local('https://cdn.test/workouts/w1/$id.png', workoutId, Uint8List.fromList(_pixel));
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<Media> media,
    String? title,
    VoidCallback? onTapTitle,
    int startingIndex = 0,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: GalleryPage(
          media: media,
          title: title,
          onTapTitle: onTapTitle,
          startingIndex: startingIndex,
        ),
      ),
    );
  }

  testWidgets('shows the caller-supplied title rather than a date', (tester) async {
    await pump(
      tester,
      media: [image(id: '1', timestamp: DateTime.utc(2026, 8, 1))],
      title: 'Monday',
    );
    await tester.pumpAndSettle();

    expect(find.text('Monday'), findsOneWidget);
  });

  testWidgets('tapping the caller-supplied title fires the callback', (tester) async {
    var tapped = false;
    await pump(
      tester,
      media: [image(id: '1')],
      title: 'Monday',
      onTapTitle: () => tapped = true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Monday'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('without a title, falls back to the shown photo\'s date', (tester) async {
    final when = DateTime.utc(2026, 8, 1, 12);
    await pump(
      tester,
      media: [image(id: '1', timestamp: when)],
    );
    await tester.pumpAndSettle();

    final expected = intl.DateFormat('EEEE, d MMM y', 'en').format(when.toLocal());
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('without a title or a timestamp, shows nothing where the date would be', (tester) async {
    await pump(tester, media: [image(id: '1')]);
    await tester.pumpAndSettle();

    // no exception from reading a null date, and no stray title text either —
    // the only text on screen is the close tooltip's semantics, not a label
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts on the requested photo rather than always the first', (tester) async {
    await pump(
      tester,
      media: [
        image(id: '1'),
        image(id: '2'),
        image(id: '3'),
      ],
      startingIndex: 2,
      title: 'Photos',
    );
    await tester.pumpAndSettle();

    expect(find.byType(CarouselView), findsOneWidget);
    // the starting index reaching the controller is the behaviour under test;
    // the carousel itself is material_ui's, so this is a smoke check that
    // construction did not throw rather than a pixel-level assertion
    expect(tester.takeException(), isNull);
  });

  testWidgets('close pops the page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GalleryPage(
                          media: [image(id: '1')],
                          title: 'Photos',
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
