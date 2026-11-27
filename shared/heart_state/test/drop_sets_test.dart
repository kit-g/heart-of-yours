import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Drop sets as one effort (#614): a drop belongs to the set before it unless
/// that is a warm-up or there is none, and an effort counts as one set.
void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  ExerciseSet set(SetType type, {bool done = true}) {
    final set = ExerciseSet(bench, setType: type);
    if (done) set.isCompleted = true;
    return set;
  }

  test('a set and the drops after it are one effort, and the next plain set starts another', () {
    final sets = [set(.warmup), set(.normal), set(.drop), set(.drop), set(.normal), set(.drop)];
    expect(sets.countEfforts(), 2);
  });

  test('a drop with no working set before it starts an effort of its own', () {
    expect([set(.drop), set(.drop)].countEfforts(), 1);
    expect([set(.warmup), set(.drop), set(.drop)].countEfforts(), 1);
  });

  test('a failure set leads an effort like a plain one', () {
    expect([set(.failure), set(.drop)].countEfforts(), 1);
  });

  test('only ticked working sets count by default, and a plan counts what it lists', () {
    final sets = [set(.normal), set(.drop, done: false), set(.normal, done: false), set(.warmup)];
    expect(sets.countEfforts(), 1);
    expect(sets.countEfforts((each) => each.setType != .warmup), 2);
  });

  test('a set never ticked is passed over, as once finishing removes it', () {
    expect([set(.normal, done: false), set(.drop)].countEfforts(), 1);
    expect([set(.normal), set(.drop, done: false), set(.drop)].countEfforts(), 1);
    expect([set(.normal), set(.warmup, done: false), set(.drop)].countEfforts(), 1);
    expect([set(.normal), set(.warmup), set(.drop)].countEfforts(), 2);
  });

  test('a discarded entry is passed over: discarding never adds a set, and its drops still count', () {
    final top = set(.normal);
    final bad = set(.drop);
    bool kept(ExerciseSet each) => isTickedWorkingSet(each) && each != top && each != bad;
    expect([top, set(.drop)].countEfforts(kept), 1);
    expect([set(.normal), bad, set(.drop)].countEfforts(kept), 1);
  });
}
