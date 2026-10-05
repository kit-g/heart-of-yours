part of 'profile.dart';

// Per-dimension chart presentation lives in one place — see [ChartDimension].
// These thin adapters keep the existing call sites in this library unchanged.
String _chartTypeCopy(BuildContext context, ChartPreferenceType option) => option.label(context);

Widget Function(double y) _getLeftLabel(ChartPreferenceType type, TextStyle? style) => type.leftLabel(style);
