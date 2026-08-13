part of '../../heart_db.dart';

const _migrations = <int, List<String>>{
  1: [
    exercises,
    syncs,
    workouts,
    workoutExercises,
    sets,
    templates,
    templatesExercises,
    exerciseDetails,
    workoutExerciseIndex1,
    workoutExerciseIndex2,
    setsIndex,
    detailsIndex,
    templatesExercisesIndex1,
    templatesExercisesIndex2,
    charts,
    chartsIndex1,
  ],
  2: [
    addExerciseUnitSystem,
    addExerciseId,
  ],
  3: [
    rebuildTemplateExercisesCreate,
    rebuildTemplateExercisesCopy,
    rebuildTemplateExercisesDrop,
    rebuildTemplateExercisesRename,
    rebuildTemplateExercisesIndex,
    addWorkoutSynced,
    backfillWorkoutSynced,
  ],
  4: [
    dedupeChartPreferences,
    chartsUniqueIndex,
    addChartsSortOrder,
    backfillChartsSortOrder,
  ],
  5: [
    addExerciseMovement,
  ],
  6: [
    addSetsExerciseIndex,
    dropChartsUniqueIndex,
    dedupeNullDataChartPreferences,
    chartsUniqueIndexNullSafe,
  ],
  7: [
    goals,
    goalsIndex,
  ],
  8: [
    templateFolders,
    templateFoldersIndex,
    addTemplateFolderId,
  ],
};
