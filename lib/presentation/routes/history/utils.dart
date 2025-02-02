part of 'history.dart';

extension on Duration {
  String formatted(BuildContext context) {
    int minutes = inMinutes % 60;
    final L(:h, :min) = L.of(context);
    return [
      if (inHours > 0) '$inHours $h',
      if (minutes > 0) '$minutes $min',
    ].join(' ');
  }
}

extension on int {
  String formatted(BuildContext context) {
    return Duration(seconds: this).formatted(context);
  }
}