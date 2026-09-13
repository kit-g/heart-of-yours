import 'package:heart_state/heart_state.dart';

class NoteStore implements ExerciseNoteService {
  final values = <String, String>{};
  final sent = <(String, String?)>[];
  bool fails = false;

  @override
  Future<Map<String, String>> read(String userId) async => Map.of(values);

  @override
  Future<void> store(String exerciseId, String userId, String? note, {bool pending = false}) async {
    switch (note) {
      case String text:
        values[exerciseId] = text;
      case null:
        values.remove(exerciseId);
    }
  }

  @override
  Future<void> sync(String exerciseId, String? note) async {
    if (fails) throw StateError('offline');
    sent.add((exerciseId, note));
  }
}
