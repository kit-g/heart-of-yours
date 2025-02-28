part of 'router.dart';

extension ContextNavigation on BuildContext {
  void goToSettings() {
    return goNamed(_settingsName);
  }

  void goToWorkoutDone(String? workoutId) {
    return goNamed(_doneName, queryParameters: {'workoutId': workoutId});
  }

  void goToWorkouts() {
    return goNamed(_workoutName);
  }

  void goToTemplateEditor({bool? newTemplate}) {
    return goNamed(_templateEditorName, queryParameters: {'newTemplate': newTemplate.toString()});
  }
}

extension on BuildContext {
  void goToPasswordRecoveryPage({String? address}) {
    return goNamed(_recoveryName, queryParameters: {'address': address});
  }

  void goToSignUp() {
    return goNamed(_signUpName);
  }
}
