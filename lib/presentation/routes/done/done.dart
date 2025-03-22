library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/logo.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';

part 'confetti.dart';

part 'counter.dart';

part 'heart.dart';

class WorkoutDone extends StatelessWidget {
  final Workout? workout;
  final VoidCallback onQuit;
  final Future<int> Function() workoutsThisWeekCallback;

  const WorkoutDone({
    super.key,
    required this.workout,
    required this.workoutsThisWeekCallback,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final L(:congratulations, :congratulationsBody, :okBang) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: onQuit,
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Motto(weight: FontWeight.normal),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
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
