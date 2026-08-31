import 'package:heart_db/heart_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every migration statement in order, mirroring the library-private
/// `_migrations` map in `lib/src/migrations/index.dart`. Keep in sync when a
/// schema version is added.
const _schema = [
  // v1
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
  // v2
  addExerciseUnitSystem,
  addExerciseId,
  // v3
  rebuildTemplateExercisesCreate,
  rebuildTemplateExercisesCopy,
  rebuildTemplateExercisesDrop,
  rebuildTemplateExercisesRename,
  rebuildTemplateExercisesIndex,
  addWorkoutSynced,
  backfillWorkoutSynced,
  // v4
  dedupeChartPreferences,
  chartsUniqueIndex,
  addChartsSortOrder,
  backfillChartsSortOrder,
  // v5
  addExerciseMovement,
  // v6
  addSetsExerciseIndex,
  dropChartsUniqueIndex,
  dedupeNullDataChartPreferences,
  chartsUniqueIndexNullSafe,
  // v7
  goals,
  goalsIndex,
  // v8
  templateFolders,
  templateFoldersIndex,
  addTemplateFolderId,
  // v9
  healthSamples,
  healthSamplesIndex,
  // v10
  addExerciseHealth,
  // v11
  rekeyExercisesCreate,
  rekeyExercisesCopy,
  rekeyWorkoutExercisesCreate,
  rekeyWorkoutExercisesCopy,
  rekeySetsCreate,
  rekeySetsCopy,
  rekeyTemplateExercisesCreate,
  rekeyTemplateExercisesCopy,
  rekeyExerciseDetailsCreate,
  rekeyExerciseDetailsCopy,
  rekeyExerciseCharts,
  rekeyDropSets,
  rekeyDropWorkoutExercises,
  rekeyDropTemplateExercises,
  rekeyDropExerciseDetails,
  rekeyDropExercises,
  rekeyExercisesRename,
  rekeyWorkoutExercisesRename,
  rekeySetsRename,
  rekeyTemplateExercisesRename,
  rekeyExerciseDetailsRename,
  rekeyWorkoutExercisesIndex1,
  rekeyWorkoutExercisesIndex2,
  rekeySetsIndex,
  rekeyTemplateExercisesIndex,
  rekeyExerciseDetailsIndex,
  addSyncsLocale,
];

/// Opens a throwaway in-memory sqlite database carrying the full production
/// schema, isolated per test.
Future<Database> openTestDatabase() {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 11,
      onCreate: (db, _) async {
        for (final statement in _schema) {
          await db.execute(statement);
        }
      },
    ),
  );
}
