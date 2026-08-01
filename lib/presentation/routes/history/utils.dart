part of 'history.dart';

extension on Duration {
  String formatted(BuildContext context) {
    final L(:h, :min, :sec) = L.of(context);
    final minutes = inMinutes % 60;
    return [
      if (inHours > 0) '$inHours $h',
      if (minutes > 0) '$minutes $min',
      // Sub-minute durations (a very short workout, or a seconds-only set) have
      // no whole hours or minutes and would otherwise render as an empty string
      // — fall back to seconds so something always shows.
      if (inHours == 0 && minutes == 0) '${inSeconds % 60} $sec',
    ].join(' ');
  }
}

extension on int {
  String formatted(BuildContext context) {
    return Duration(seconds: this).formatted(context);
  }
}
