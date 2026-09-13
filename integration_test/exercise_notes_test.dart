import 'package:integration_test/integration_test.dart';

import '../test/exercise_notes_test.dart' as notes;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  notes.exerciseNoteTests(
    useDeviceSize: true,
    onFrame: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
