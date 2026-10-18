// The time a program's sessions go in the calendar at (#391), picked the
// platform's way: the wheel on an iPhone, the clock elsewhere.
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/date_picker.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<TimeOfDay?> pick(WidgetTester tester, TargetPlatform platform, {bool twentyFour = false}) async {
    TimeOfDay? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: twentyFour),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                picked = await showAdaptiveTimePicker(context, initial: const TimeOfDay(hour: 18, minute: 0)),
            child: const Text('pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets("an iPhone gets the wheel, in the device's hour format", (tester) async {
    await pick(tester, TargetPlatform.iOS, twentyFour: true);
    final wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    expect(wheel.mode, CupertinoDatePickerMode.time);
    expect(wheel.use24hFormat, isTrue);
    expect(find.byType(TimePickerDialog), findsNothing);
  });

  testWidgets('elsewhere, the Material clock', (tester) async {
    await pick(tester, TargetPlatform.android);
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });
}
