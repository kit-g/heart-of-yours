// Haptics on the shared controls: a pick or a switch that changes something
// clicks once; one that changes nothing stays quiet.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/setting_picker.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
        return null;
      },
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('the segmented control clicks on a new pick, not on the current one (${platform.name})', (
      tester,
    ) async {
      final value = ValueNotifier('kg');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder(
                valueListenable: value,
                builder: (_, current, _) => SettingSwitcher<String>(
                  value: current,
                  children: const {'kg': Text('kg'), 'lb': Text('lb')},
                  onValueChanged: (picked) => value.value = picked ?? current,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);

      await tester.tap(find.text('lb'));
      await tester.pumpAndSettle();
      expect(value.value, 'lb');
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });
  }
}
