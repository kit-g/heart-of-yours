import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/shortcuts.dart';

void main() {
  group('ShortcutLink.parse', () {
    test('start with a template, as the platform hands the link over', () {
      final link = ShortcutLink.parse(Uri.parse('heart://app/start?template=t1'));
      expect(link, isA<StartWorkoutLink>().having((link) => link.templateId, 'templateId', 't1'));
    });

    test('start with no template is a blank workout', () {
      expect(ShortcutLink.parse(Uri.parse('heart://app/start')), isA<StartWorkoutLink>());
      expect(
        ShortcutLink.parse(Uri.parse('/start')),
        isA<StartWorkoutLink>().having((link) => link.templateId, 'templateId', isNull),
      );
    });

    test('an empty template parameter is no template', () {
      expect(
        ShortcutLink.parse(Uri.parse('heart://app/start?template=')),
        isA<StartWorkoutLink>().having((link) => link.templateId, 'templateId', isNull),
      );
    });

    test('finish', () {
      expect(ShortcutLink.parse(Uri.parse('heart://app/finish')), isA<FinishWorkoutLink>());
    });

    test('a screen is not a command, and neither is a verb this version does not know', () {
      expect(ShortcutLink.parse(Uri.parse('heart://app/exercises/bench')), isNull);
      expect(ShortcutLink.parse(Uri.parse('/profile/settings')), isNull);
      expect(ShortcutLink.parse(Uri.parse('heart://app/rest?seconds=90')), isNull);
      expect(ShortcutLink.parse(Uri.parse('heart://app/')), isNull);
    });
  });
}
