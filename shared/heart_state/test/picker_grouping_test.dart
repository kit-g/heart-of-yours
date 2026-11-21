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
        patterns: () => ['vertical_press', 'horizontal_press', 'squat_bilateral', 'deadlift_floor'],
      );
      expect(shape(groups), [
        'movement:vertical_press: id-thruster',
        'movement:horizontal_press: id-bench',
        'movement:squat_bilateral: id-thruster',
        // patterns the order did not name keep a heading, after it
        'movement:horizontal_row: id-row',
        'movement:chest_fly: id-fly',
        'movement: id-custom',
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

    test('a target and a category of one name are two groups, and Other is no pattern\'s', () {
      expect(const CategoryGroup(.cardio).id, isNot(const TargetGroup(.cardio).id));
      expect(const NoPatternGroup().id, isNot(const PatternGroup('').id));
    });

    test('only movement asks for the library\'s patterns', () {
      var asked = 0;
      List<String> patterns() {
        asked++;
        return const [];
      }

      for (final by in [PickerGrouping.none, PickerGrouping.category, PickerGrouping.target]) {
        groupExercises(library, by, patterns: patterns);
      }
      expect(asked, 0);
      groupExercises(library, .movement, patterns: patterns);
      expect(asked, 1);
    });
  });

  group('representativeOf (#711)', () {
    Exercise pictured(String key) {
      return Exercise.fromJson({
        'id': 'id-$key',
        'key': key,
        'name': key,
        'category': 'Barbell',
        'target': 'Legs',
        'thumbnail': {'link': 'https://cdn.example/$key.png'},
      });
    }

    final box = pictured('box-squat-barbell');
    final front = pictured('front-squat-barbell');
    final back = pictured('squat-barbell');
    final custom = lift('my-squat', category: 'Machine', target: 'Legs');

    test('the one done most, whatever the order', () {
      final done = {front.id: 4, back.id: 2};
      expect(representativeOf([box, front, back], timesDone: (id) => done[id] ?? 0), front);
    });

    test('with nothing done, the best-known one rather than the first', () {
      expect(representativeOf([box, front, back], timesDone: (_) => 0), back);
      expect(representativeOf([box, front, back]), back);
    });

    test('with nothing done and no staple, the first in the list', () {
      expect(representativeOf([box, front]), box);
    });

    test('a picture beats being done most: a custom exercise has none to show', () {
      final done = {custom.id: 50};
      expect(representativeOf([custom, box], timesDone: (id) => done[id] ?? 0), box);
    });

    test('a group with no picture at all still has one, the one done most, and no members have none', () {
      final other = lift('my-lunge', target: 'Legs');
      final done = {other.id: 3};
      expect(representativeOf([custom, other], timesDone: (id) => done[id] ?? 0), other);
      expect(representativeOf(const []), isNull);
    });
  });

  group('PreviousExercises.timesDone (#711)', () {
    test('reads the sessions last time carries, and 0 for one never done', () async {
      final service = _Previous({
        'id-bench': [
          {'weight': 100, 'reps': 5, 'workout_start': '2026-10-03T08:00:00.000Z', 'sessions': 7},
        ],
        // a row read before the count existed
        'id-row': [
          {'weight': 60, 'reps': 8, 'workout_start': '2026-10-01T08:00:00.000Z'},
        ],
      });
      final previous = PreviousExercises(service: service)..userId = 'u1';
      await previous.init();

      expect(previous.timesDone('id-bench'), 7);
      expect(previous.timesDone('id-row'), 0);
      expect(previous.timesDone('id-never'), 0);
    });
  });

  group('Preferences', () {
    test('the grouping is none until chosen, then the choice, as a screen choice with its time', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = Preferences();
      await preferences.init();
      expect(preferences.pickerGrouping, PickerGrouping.none);
      expect(preferences.screenChoices, isEmpty);

      var notified = 0;
      preferences.addListener(() => notified++);
      preferences.setPickerGrouping(.movement);

      expect(preferences.pickerGrouping, PickerGrouping.movement);
      expect(preferences.screenChoices[ScreenChoice.pickerGrouping]?.value, 'movement');
      expect(notified, 1);

      // the grouping already in force is not a new choice
      preferences.setPickerGrouping(.movement);
      expect(notified, 1);
    });

    test('the choice outlives the launch', () async {
      SharedPreferences.setMockInitialValues({
        'screen-pickerGrouping': 'target',
        'screen-pickerGrouping-at': '2026-11-01T10:00:00.000Z',
      });
      final preferences = Preferences();
      await preferences.init();
      expect(preferences.pickerGrouping, PickerGrouping.target);
    });

    test('groups start folded, and one opened stays open across launches, waking only its own listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = Preferences();
      await preferences.init();
      const chest = TargetGroup(.chest);
      expect(preferences.openPickerGroups.value, isEmpty);

      var everyone = 0;
      var folds = 0;
      preferences.addListener(() => everyone++);
      preferences.openPickerGroups.addListener(() => folds++);
      preferences.togglePickerGroup(chest.id);

      expect(preferences.openPickerGroups.value, {chest.id});
      expect(folds, 1);
      expect(everyone, 0);

      final relaunched = Preferences();
      await relaunched.init();
      expect(relaunched.openPickerGroups.value, {chest.id});

      relaunched.togglePickerGroup(chest.id);
      expect(relaunched.openPickerGroups.value, isEmpty);
    });

    test(
      'a fold before the store has loaded applies at once, is kept when it loads, and the set handed out cannot be changed',
      () async {
        SharedPreferences.setMockInitialValues({
          'openPickerGroups': ['target:back'],
        });
        final preferences = Preferences();
        const chest = TargetGroup(.chest);
        const legs = TargetGroup(.legs);

        preferences.togglePickerGroup(chest.id);
        expect(preferences.openPickerGroups.value, {chest.id});
        preferences.togglePickerGroup(legs.id);
        preferences.togglePickerGroup(legs.id);

        await preferences.init();
        expect(preferences.openPickerGroups.value, {'target:back', chest.id});
        expect(() => preferences.openPickerGroups.value.add('x'), throwsUnsupportedError);

        final relaunched = Preferences();
        await relaunched.init();
        expect(relaunched.openPickerGroups.value, {'target:back', chest.id});
      },
    );
  });
}

class _Previous implements PreviousExerciseService {
  final Map<ExerciseId, List<Map<String, dynamic>>> sets;

  new(this.sets);

  @override
  Future<Map<ExerciseId, List<Map<String, dynamic>>>> getPreviousSets(String userId) async => sets;
}
