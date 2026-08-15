import 'package:flutter/services.dart';

/// Keeps a field to a decimal number of at most [n] digits.
///
/// Rejects rather than sanitizes: an edit that would make the text invalid is
/// dropped, so the field never shows a half-formed number the parser would
/// later refuse.
class NDigitFloatingPointFormatter extends TextInputFormatter {
  final int n;

  const new({this.n = 5});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    // ensure only digits and at most one decimal point are present
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;

    // if only a decimal point is entered, reject it (prevents just ".")
    if (text == '.') return oldValue;

    if (text.endsWith('.') && text.length >= n) return oldValue;
    // split into integer and decimal parts
    final parts = text.split('.');

    // count total digits (excluding the decimal point)
    final totalDigits = parts.fold<int>(0, (sum, part) => sum + part.length);

    // enforce max digits (excluding the decimal point)
    if (totalDigits > n) return oldValue;

    return newValue;
  }
}

/// Types a duration right-to-left: digits fill seconds first, then minutes,
/// then hours, so `130` reads as `1:30` without the user placing a colon.
class TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // remove any existing formatting
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');

    // allow only digits and reject input longer than 5 digits
    if (!RegExp(r'^[1-9]\d{0,4}$').hasMatch(raw)) return oldValue;

    final formatted = switch (raw.length) {
      1 => '00:${raw.padLeft(2, '0')}',
      2 => '00:$raw',
      3 => '${raw[0]}:${raw.substring(1).padLeft(2, '0')}',
      4 => '${raw.substring(0, 2)}:${raw.substring(2).padLeft(2, '0')}',
      5 => '${raw[0]}:${raw.substring(1, 3)}:${raw.substring(3).padLeft(2, '0')}',
      _ => '',
    };

    // formatted time with the correct cursor position
    return TextEditingValue(
      text: formatted,
      selection: .collapsed(offset: formatted.length),
    );
  }
}

/// Seconds behind a [TimeFormatter]-shaped string (`ss`, `mm:ss` or `h:mm:ss`),
/// or null when it does not describe one.
int? parseDuration(String text) {
  final parts = text.split(':');
  if (parts.length > 3) return null;

  var seconds = 0;
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null) return null;
    seconds = seconds * 60 + value;
  }
  return seconds;
}
