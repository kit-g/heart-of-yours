library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart/presentation/widgets/logo.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

part 'confetti.dart';
part 'counter.dart';
part 'heart.dart';
part 'achievements.dart';
part 'records.dart';

class WorkoutDone extends StatelessWidget {
  final Workout? workout;
  final VoidCallback onQuit;
  final Future<int> Function() workoutsThisWeekCallback;

  /// The rungs this session earned. Resolved here rather than passed in
  /// because it has to wait for the workout to be written — this screen is
  /// pushed the moment finishing starts, not when it lands.
  final Future<List<GoalAchievement>> Function() achievementsCallback;

  /// The personal records this session set, under the same contract as
  /// [achievementsCallback]: resolved late, against the written workout.
  final Future<List<AchievedRecord>> Function() recordsCallback;

  const new({
    super.key,
    required this.workout,
    required this.workoutsThisWeekCallback,
    required this.achievementsCallback,
    required this.recordsCallback,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final L(:congratulations, :congratulationsBody, :okBang, :close) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: close,
          onPressed: onQuit,
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Motto(weight: FontWeight.normal),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Scrolls only when it has to, and centres otherwise — the same
            // construction as the login page and the onboarding carousel.
            //
            // It used to be a bare `Center`, which is fine for the screen this
            // usually is: a count, a line of congratulation, and the workout.
            // But `_Records` is as long as the session was good, and the first
            // workout on a new account sets a record on *every* exercise it
            // touches, because there is nothing to beat yet. Each one is a
            // line, and together they pushed the OK button off the bottom of
            // the phone with no way to reach it — on the one screen a new user
            // sees at the end of their first workout.
            //
            // The confetti stays outside this: it is positioned against the
            // viewport and should not travel with the content.
            LayoutBuilder(
              builder: (context, viewport) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewport.maxHeight),
                    child: Center(
                      child: Column(
                        // the scroll view gives it unbounded height; `.max`
                        // would ask for infinity and throw
                        mainAxisSize: .min,
                        children: [
                          const SizedBox(height: 36),
                          FutureBuilder<int>(
                            future: workoutsThisWeekCallback(),
                            builder: (_, future) {
                              final count = future.data;
                              if (count == null) return const SizedBox.shrink();
                              return LayoutBuilder(
                                builder: (_, constraints) {
                                  const size = 50.0;
                                  // how many hearts will fit into the screen
                                  final maxPulses = ((constraints.maxWidth - 10) / size).floor();
                                  // we'll render how many workouts there have been this week
                                  // or whatever the screen allows, whichever is smaller
                                  return _Counter(
                                    count: min(count, maxPulses),
                                    color: colorScheme.error,
                                    duration: 300,
                                    size: size,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Stack(
                            children: [
                              Text(
                                congratulations,
                                style: textTheme.headlineSmall,
                              ),
                              const Positioned.fill(
                                child: Confetti(particleCount: 70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            congratulationsBody,
                            style: textTheme.bodyLarge,
                          ),
                          _Achievements(callback: achievementsCallback),
                          _Records(callback: recordsCallback),
                          const SizedBox(height: 72),
                          if (workout case Workout workout)
                            WorkoutItem(
                              workout: workout,
                              showsMenuButton: false,
                            ),
                          const SizedBox(height: 72),
                          OutlinedButton(
                            onPressed: onQuit,
                            child: Text(okBang),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Builder(
              builder: (context) {
                final size = MediaQuery.sizeOf(context);
                return Positioned(
                  bottom: size.height * .2,
                  right: size.width * .3,
                  child: const Confetti(particleCount: 70),
                );
              },
            ),
            Builder(
              builder: (context) {
                final size = MediaQuery.sizeOf(context);
                return Positioned(
                  bottom: size.height * .5,
                  left: size.width * .3,
                  child: const Confetti(particleCount: 90),
                );
              },
            ),
            Builder(
              builder: (context) {
                final size = MediaQuery.sizeOf(context);
                return Positioned(
                  bottom: size.height * .1,
                  left: size.width * .3,
                  child: const Confetti(particleCount: 90),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
