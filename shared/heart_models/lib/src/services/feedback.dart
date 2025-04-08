import 'dart:typed_data';

abstract interface class FeedbackService {
  Future<bool> submitFeedback({String? feedback, Uint8List? screenshot});
}
