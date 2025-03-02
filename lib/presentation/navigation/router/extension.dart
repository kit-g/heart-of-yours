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
}
