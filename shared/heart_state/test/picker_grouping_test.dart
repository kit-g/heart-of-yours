import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Grouping the picker's list by category, target or movement (#620), and the
/// device's side of the choice.
void main() {
  Exercise lift(String key, {String category = 'Barbell', String target = 'Chest', List<String> patterns = const []}) {
    return Exercise.fromJson({
      'id': 'id-$key',
      'key': key,
      'name': key,
      'category': category,
      'target': target,
      if (patterns.isNotEmpty) 'movement': {'groups': patterns},
    });
  }

  final bench = lift('bench', patterns: ['horizontal_press']);
  final row = lift('row', target: 'Back', patterns: ['horizontal_row']);
  final fly = lift('fly', category: 'Dumbbell', patterns: ['chest_fly']);
  // trains two patterns, so it is under both
  final thruster = lift('thruster', target: 'Legs', patterns: ['squat_bilateral', 'vertical_press']);
  final custom = lift('custom', category: 'Machine');
  final library = [bench, row, fly, thruster, custom];

  /// Each group as `id: members`, which compares by value.
  List<String> shape(List<GroupedExercises> groups) {
    return [
      for (final (:group, :exercises) in groups) '${group.id}: ${exercises.map((each) => each.id).join(', ')}',
    ];
  }

  group('groupExercises', () {
    test('none has no headings', () {
      expect(groupExercises(library, .none), isEmpty);
    });

    test('by category: in the menu\'s order, each keeping the list\'s order, none empty', () {
      expect(shape(groupExercises(library, .category)), [
        'category:machine: id-custom',
        'category:dumbbell: id-fly',
        'category:barbell: id-bench, id-row, id-thruster',
      ]);
    });

    test('by target: in the menu\'s order', () {
      expect(shape(groupExercises(library, .target)), [
        'target:back: id-row',
        'target:chest: id-bench, id-fly, id-custom',
        'target:legs: id-thruster',
      ]);
    });

    test('by movement: in the given order, one with several patterns under each, none at all under Other, last', () {
      final groups = groupExercises(
        library,
        .movement,
        patterns: ['vertical_press', 'horizontal_press', 'squat_bilateral', 'deadlift_floor'],
      );
      expect(shape(groups), [
        'movement:vertical_press: id-thruster',
        'movement:horizontal_press: id-bench',
        'movement:squat_bilateral: id-thruster',
        // patterns the order did not name keep a heading, after it
        'movement:horizontal_row: id-row',
        'movement:chest_fly: id-fly',
        'movement:: id-custom',
      ]);
      expect(groups.last.group, const NoPatternGroup());
      expect(groups.first.group, const PatternGroup('vertical_press'));
    });

    test('a filtered list leaves out what it emptied', () {
      expect(shape(groupExercises([bench, fly], .movement)), [
        'movement:horizontal_press: id-bench',
        'movement:chest_fly: id-fly',
      ]);
      expect(groupExercises(const [], .category), isEmpty);
    });

    test('a target and a category of one name are two groups', () {
      expect(const CategoryGroup(.cardio).id, isNot(const TargetGroup(.cardio).id));
    });
  });

  group('the settings codec', () {
    test('reads what it wrote, keeping every other key', () {
      const settings = Settings(themeMode: 'dark', extra: {'kept': 1, 'features': {}});
      for (final grouping in PickerGrouping.values) {
        final written = withPickerGrouping(settings, grouping);
        expect(pickerGroupingOf(written), grouping);
        expect(written.extra['kept'], 1);
        expect(written.extra['features'], isEmpty);
        expect(written.themeMode, 'dark');
        // through the wire and back
        expect(pickerGroupingOf(Settings.fromJson(written.toMap())), grouping);
      }
    });

    test('nothing, or a grouping from a newer version, reads as no choice', () {
      expect(pickerGroupingOf(const Settings()), isNull);
      expect(pickerGroupingOf(const Settings(extra: {'pickerGrouping': 'equipment'})), isNull);
      expect(pickerGroupingOf(const Settings(extra: {'pickerGrouping': 3})), isNull);
    });
  });

  group('Preferences', () {
    test('the grouping is none until chosen, then the choice, owed to the account', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = Preferences();
      await preferences.init();
      expect(preferences.pickerGrouping, PickerGrouping.none);
      expect(preferences.chosenPickerGrouping, isNull);

      var notified = 0;
      preferences.addListener(() => notified++);
      preferences.setPickerGrouping(.movement);

      expect(preferences.pickerGrouping, PickerGrouping.movement);
      expect(preferences.pickerGroupingOwed, isTrue);
      expect(notified, 1);

      preferences.settlePickerGrouping();
      expect(preferences.pickerGroupingOwed, isFalse);
    });

    test('the choice outlives the launch', () async {
      SharedPreferences.setMockInitialValues({'pickerGrouping': 'target'});
      final preferences = Preferences();
      await preferences.init();
      expect(preferences.pickerGrouping, PickerGrouping.target);
    });

    test('groups start folded, and one opened stays open across launches', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = Preferences();
      await preferences.init();
      const chest = TargetGroup(.chest);
      expect(preferences.isPickerGroupOpen(chest.id), isFalse);

      preferences.togglePickerGroup(chest.id);
      expect(preferences.isPickerGroupOpen(chest.id), isTrue);
      expect(preferences.isPickerGroupOpen(const CategoryGroup(.barbell).id), isFalse);

      final relaunched = Preferences();
      await relaunched.init();
      expect(relaunched.isPickerGroupOpen(chest.id), isTrue);

      relaunched.togglePickerGroup(chest.id);
      expect(relaunched.isPickerGroupOpen(chest.id), isFalse);
    });
  });
}
