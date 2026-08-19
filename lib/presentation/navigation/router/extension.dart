part of 'router.dart';

extension ContextNavigation on BuildContext {
  void goToWorkoutDone(String? workoutId) {
    return goNamed(_doneName, queryParameters: {'workoutId': workoutId});
  }
}

extension on BuildContext {
  void goToSettings() {
    return goNamed(_settingsName);
  }

  void goToProfile() {
    return goNamed(_profileName);
  }

  void goToPasswordRecoveryPage({String? address}) {
    return goNamed(_recoveryName, queryParameters: {'address': address});
  }

  void goToSignUp({String? address}) {
    return goNamed(_signUpName, queryParameters: {'address': address});
  }

  void goToWorkouts() {
    return goNamed(_workoutName);
  }

  void goToTemplateEditor({bool? newTemplate}) {
    return goNamed(_templateEditorName, queryParameters: {'newTemplate': newTemplate.toString()});
  }

  void goToAccountManagement() {
    return goNamed(_accountManagementName);
  }

  void goToImportData() {
    return goNamed(_importDataName);
  }

  void goToAvatar() {
    return goNamed(_avatarName);
  }

  void goToHistory() {
    return goNamed(_historyName);
  }

  void goToWorkoutEditor(String workoutId) {
    return go('$_historyPath/$workoutId');
  }

  /// Pushes on a phone, replaces on a tablet.
  ///
  /// Compact puts the detail on top of the list as its own screen, so pushing
  /// is right and the back arrow means what it says. Wide keeps the detail in a
  /// pane that never goes away, and pushing there quietly stacks every exercise
  /// looked at — which is what made the pane's back button walk through them
  /// one at a time instead of closing.
  Future<Object?> goToExerciseDetail(String exerciseId) {
    final path = '$_exercisesPath/$exerciseId';

    switch (LayoutProvider.of(this)) {
      case .compact:
        return push(path);
      case .wide:
        go(path);
        return Future<Object?>.value();
    }
  }

  /// Empties the two-pane detail without leaving the exercises stack.
  void closeExerciseDetail() {
    return go(_exercisesPath);
  }

  void goToExerciseArchive() {
    return goNamed(_exerciseArchive);
  }

  /// Opens the library showing only [filter], replacing whatever was filtered
  /// before — arriving from a chip means "show me these", not "narrow what I
  /// had", and the previous filters are not visible from where the chip was
  /// tapped.
  void goToFilteredExercises(ExerciseFilter filter) {
    Exercises.of(this)
      ..clearFilters()
      ..addFilter(filter);
    return goNamed(_exercisesName);
  }

  Future<void> goToActiveWorkout() {
    return _pushActiveWorkoutOnce(GoRouter.of(this));
  }

  Future<void> goToGallery(Iterable<Media> media, {required int startingIndex, String? workoutId}) {
    return push(_galleryPath, extra: (media, startingIndex, workoutId));
  }
}
