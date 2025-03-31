import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

class PreviousSet extends StatelessWidget {
  final Exercise exercise;
  final Map<String, dynamic> previousValue;
  final Preferences prefs;

  const PreviousSet({
    super.key,
    required this.previousValue,
    required this.exercise,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    final L(:lbs, :kg, :reps, :milesPlural, :km) = L.of(context);

    switch (exercise.category) {
      case Category.barbell:
      case Category.dumbbell:
      case Category.machine:
      case Category.assistedBodyWeight:
      case Category.weightedBodyWeight:
        final unit = switch (prefs.weightUnit) {
          MeasurementUnit.imperial => lbs,
          MeasurementUnit.metric => kg,
        };
        return switch (previousValue) {
          {'reps': int reps, 'weight': num weight} => Text(
              '${prefs.weight(weight)}$unit x $reps',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          _ => const Text(_emptyValue),
        };

      case Category.repsOnly:
        return switch (previousValue) {
          {'reps': int value} => Text(
              '$value $reps ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          _ => const Text(_emptyValue),
        };
      case Category.duration:
        return switch (previousValue) {
          {'duration': num duration} => Text(
              Duration(seconds: duration.toInt()).formatted(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          _ => const Text(_emptyValue),
        };
      case Category.cardio:
        final unit = switch (prefs.distanceUnit) {
          MeasurementUnit.imperial => milesPlural,
          MeasurementUnit.metric => km,
        };
        return switch (previousValue) {
          {'duration': num duration, 'distance': num distance} => Text(
              '${prefs.distance(distance)}$unit | ${Duration(seconds: duration.toInt()).formatted()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          _ => const Text(_emptyValue),
        };
    }
  }
}

extension on Duration {
  String formatted() {
    final minutes = _pad(inMinutes.remainder(60));
    final seconds = _pad(inSeconds.remainder(60));
    return switch (inHours) {
      > 0 => '${_pad(inHours)}:$minutes:$seconds',
      _ => '$minutes:$seconds',
    };
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

const _emptyValue = '-';
