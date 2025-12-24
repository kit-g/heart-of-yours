part of '../heart_db.dart';

const _migrations = <int, List<String>>{
  1: [
    sql.exercises,
    sql.syncs,
    sql.workouts,
    sql.workoutExercises,
    sql.sets,
    sql.templates,
    sql.templatesExercises,
    sql.exerciseDetails,
    sql.workoutExerciseIndex1,
    sql.workoutExerciseIndex2,
    sql.setsIndex,
    sql.detailsIndex,
    sql.templatesExercisesIndex1,
    sql.templatesExercisesIndex2,
    sql.charts,
    sql.chartsIndex1,
  ],
};
