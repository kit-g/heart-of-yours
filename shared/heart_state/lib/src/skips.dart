import 'package:heart_models/heart_models.dart';

/// Why the user didn't train (#312): one tap, offered once per skip and never
/// required. [value] is the wire spelling the server checks
/// (`TrainingSkip.reason`), and never changes once shipped.
enum SkipReason {
  tired('tired'),
  sore('sore'),
  sick('sick'),
  busy('busy'),
  justNo('just_no');

  final String value;

  new(this.value);

  /// Null for none, or a tag this build doesn't know: a newer build's, kept on
  /// the skip as it came.
  static SkipReason? of(String? value) => values.where((each) => each.value == value).firstOrNull;
}

/// Which skips a screen shows (#312): a program's under Programs, a plain day
/// under "Not today". A skip whose program was deleted still names its
/// session, and stays with Programs.
extension SkipShown on TrainingSkip {
  bool get isDay => programId == null && templateId == null;
}
