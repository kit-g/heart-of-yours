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

  void goToAvatar() {
    return goNamed(_avatarName);
  }

  void goToHistory() {
    return goNamed(_historyName);
  }

  void goToWorkoutEditor(String workoutId) {
    return go('$_historyPath/$workoutId');
  }

  Future<Object?> goToExerciseDetail(String exerciseId) {
    return push('$_exercisesPath/$exerciseId');
  }

  void goToExerciseArchive() {
    return goNamed(_exerciseArchive);
  }

  Future<void> goToActiveWorkout() {
    return push(_activeWorkoutPath);
  }

  Future<void> goToGallery(Iterable<Media> media, {required int startingIndex, String? workoutId}) {
    return push(_galleryPath, extra: (media, startingIndex, workoutId));
  }
}
