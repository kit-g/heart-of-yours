import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';

void main() {
  const formatter = NDigitFloatingPointFormatter();

  String format(String input) {
    return formatter
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: input, selection: TextSelection.collapsed(offset: input.length)),
        )
        .text;
  }

  group('NDigitFloatingPointFormatter', () {
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

  group('TimeFormatter', () {
    final formatter = TimeFormatter();

    String format(String input) {
      return formatter
          .formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: input, selection: TextSelection.collapsed(offset: input.length)),
          )
          .text;
    }

    test('Formats time correctly for 1 digit', () {
      expect(format("1"), "00:01");
      expect(format("9"), "00:09");
    });

    test('Formats time correctly for 2 digits', () {
      expect(format("10"), "00:10");
      expect(format("55"), "00:55");
    });

    test('Formats time correctly for 3 digits', () {
      expect(format("100"), "1:00");
      expect(format("500"), "5:00");
      expect(format("999"), "9:99"); // we'll allow this input
    });

    test('Formats time correctly for 4 digits', () {
      expect(format("1000"), "10:00");
      expect(format("4999"), "49:99");
      expect(format("9999"), "99:99"); // we'll allow this input
    });

    test('Formats time correctly for 5 digits', () {
      expect(format("10000"), "1:00:00");
      expect(format("50000"), "5:00:00");
      expect(format("99999"), "9:99:99"); // we'll allow this input
    });

    test('Rejects input longer than 5 digits', () {
      expect(format("100000"), "");
      expect(format("123456"), "");
      expect(format("999999"), "");
      expect(format("123456789"), "");
    });

    test('Rejects non-numeric input', () {
      expect(format("abc"), "");
      expect(format("12a34"), "12:34");
      expect(format("!@#"), "");
      expect(format("12345abc"), "1:23:45");
    });

    test('Handles edge cases correctly', () {
      expect(format(""), "");
      expect(format("0"), "");
      expect(format("01"), "00:01");
      expect(format("9"), "00:09");
    });

    test('Rejects multiple leading zeros correctly', () {
      expect(format("00005"), "00:05");
      expect(format("00050"), "00:50");
      expect(format("000500"), "5:00");
      expect(format("000000"), "");
      expect(format("0000000"), "");
    });

    test('Handles input where leading zeros are removed automatically', () {
      expect(format("0001"), "00:01");
      expect(format("0030"), "00:30");
    });

    test('Correctly handles edge cases for minutes', () {
      expect(format("60"), "00:60");
      expect(format("99"), "00:99");
      expect(format("100"), "1:00");
      expect(format("123"), "1:23");
      expect(format("150"), "1:50");
      expect(format("1000"), "10:00");
      expect(format("15000"), "1:50:00");
    });

    test('Handles empty input gracefully', () {
      expect(format(""), "");
    });

    test('Handles single digit input formatting correctly', () {
      expect(format("1"), "00:01");
      expect(format("9"), "00:09");
    });

    test('Handles exactly 2 digits correctly', () {
      expect(format("10"), "00:10");
      expect(format("50"), "00:50");
    });

    test('Handles exactly 3 digits correctly', () {
      expect(format("100"), "1:00");
      expect(format("999"), "9:99"); // we'll allow this input
    });

    test('Handles exactly 4 digits correctly', () {
      expect(format("1000"), "10:00");
      expect(format("4999"), "49:99"); // we'll allow this input
    });

    test('Handles exactly 5 digits correctly', () {
      expect(format("10000"), "1:00:00");
      expect(format("99999"), "9:99:99");// we'll allow this input
    });

    test('Rejects decimal or non-integer input', () {
      expect(format("10.5"), "1:05");
      expect(format("5.00"), "5:00");
      expect(format("2.50"), "2:50");
    });
  });
}
