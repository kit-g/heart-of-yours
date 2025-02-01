import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/workout/active_workout.dart';

void main() {
  const formatter = NDigitFloatingPointFormatter();

  String format(String input) {
    return formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: input, selection: TextSelection.collapsed(offset: input.length)),
    ).text;
  }

  group('FiveDigitFloatingPointFormatter', () {
    test('Allows valid inputs with up to 5 digits total', () {
      expect(format('12345'), '12345');
      expect(format('1.23'), '1.23');
      expect(format('123.4'), '123.4');
      expect(format('12.34'), '12.34');
      expect(format('1234.5'), '1234.5');
      expect(format('12.345'), '12.345');
      expect(format('123.45'), '123.45');
    });

    test('Rejects inputs with more than 5 digits total', () {
      expect(format('123456'), ''); // Input is rejected
      expect(format('1234.56'), ''); // Input is rejected
      expect(format('12.3456'), ''); // Input is rejected
      expect(format('123456.78'), ''); // Input is rejected
    });

    test('Rejects inputs with invalid formatting', () {
      expect(format('.'), ''); // Just a dot is invalid
      expect(format('12345.'), ''); // No trailing dot
      expect(format('..123'), ''); // No multiple dots
      expect(format('abc'), ''); // No non-numeric input
      expect(format('12a.34'), ''); // Filters out non-numeric
    });

    test('Handles incremental input correctly', () {
      expect(format('1'), '1');
      expect(format('12'), '12');
      expect(format('123'), '123');
      expect(format('1234'), '1234');
      expect(format('12345'), '12345');
      expect(format('12345.'), ''); // Prevents trailing dot
      expect(format('123.45'), '123.45');
    });

    test('Handles edge cases', () {
      expect(format(''), ''); // Empty input is allowed
      expect(format('0'), '0'); // Single zero is valid
      expect(format('0.0'), '0.0'); // Valid decimal input
      expect(format('00.01'), '00.01'); // Valid with leading zero
      expect(format('12345.67'), ''); // Too long, input rejected
    });
  });
}
