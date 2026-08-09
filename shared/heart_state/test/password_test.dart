// PasswordPolicy is not in firebase_auth's re-export list, and this suite may
// not touch pubspec.yaml, so it is pulled from the transitive package directly.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart' show PasswordPolicy;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';

/// Builds a [PasswordValidationStatus] over a policy with the given
/// strength options; omitted options are absent from the policy, matching
/// what the backend sends when a rule is not configured.
PasswordValidationStatus status({
  int? minLength,
  int? maxLength,
  bool? lowercase,
  bool? uppercase,
  bool? digits,
}) {
  final policy = PasswordPolicy({
    'customStrengthOptions': {
      'minPasswordLength': ?minLength,
      'maxPasswordLength': ?maxLength,
      'containsLowercaseCharacter': ?lowercase,
      'containsUppercaseCharacter': ?uppercase,
      'containsNumericCharacter': ?digits,
    },
  });
  return PasswordValidationStatus(true, policy);
}

void main() {
  group('satisfiesMinPasswordLength', () {
    test('uses the policy minimum as an inclusive bound', () {
      final sut = status(minLength: 8);
      expect(sut.satisfiesMinPasswordLength('1234567'), isFalse);
      expect(sut.satisfiesMinPasswordLength('12345678'), isTrue);
    });

    test('falls back to the firebase default of 6 when unspecified', () {
      final sut = status();
      expect(sut.satisfiesMinPasswordLength('12345'), isFalse);
      expect(sut.satisfiesMinPasswordLength('123456'), isTrue);
    });
  });

  group('satisfiesMaxPasswordLength', () {
    test('uses the policy maximum as an inclusive bound', () {
      final sut = status(maxLength: 8);
      expect(sut.satisfiesMaxPasswordLength('12345678'), isTrue);
      expect(sut.satisfiesMaxPasswordLength('123456789'), isFalse);
    });

    test('falls back to 120 when the policy has no maximum', () {
      final sut = status();
      expect(sut.satisfiesMaxPasswordLength('a' * 120), isTrue);
      expect(sut.satisfiesMaxPasswordLength('a' * 121), isFalse);
    });
  });

  group('character requirements', () {
    test('digits pass everything when the rule is absent or off', () {
      expect(status().satisfiesDigitRequirement('letters'), isTrue);
      expect(status(digits: false).satisfiesDigitRequirement('letters'), isTrue);
    });

    test('digits are demanded when the rule is on', () {
      final sut = status(digits: true);
      expect(sut.satisfiesDigitRequirement('letters'), isFalse);
      expect(sut.satisfiesDigitRequirement('letters1'), isTrue);
    });

    test('uppercase passes everything when the rule is absent or off', () {
      expect(status().satisfiesUpperCaseRequirement('lower'), isTrue);
      expect(status(uppercase: false).satisfiesUpperCaseRequirement('lower'), isTrue);
    });

    test('uppercase is demanded when the rule is on', () {
      final sut = status(uppercase: true);
      expect(sut.satisfiesUpperCaseRequirement('lower'), isFalse);
      expect(sut.satisfiesUpperCaseRequirement('Lower'), isTrue);
    });

    test('lowercase passes everything when the rule is absent or off', () {
      expect(status().satisfiesLowerCaseRequirement('UPPER'), isTrue);
      expect(status(lowercase: false).satisfiesLowerCaseRequirement('UPPER'), isTrue);
    });

    test('lowercase is demanded when the rule is on', () {
      final sut = status(lowercase: true);
      expect(sut.satisfiesLowerCaseRequirement('UPPER'), isFalse);
      expect(sut.satisfiesLowerCaseRequirement('UPPERs'), isTrue);
    });
  });

  group('copyWith', () {
    test('overrides only the given flags and keeps the rest', () {
      final sut = status();
      sut
        ..meetsMinPasswordLength = true
        ..meetsMaxPasswordLength = true
        ..meetsLowercaseRequirement = true
        ..meetsUppercaseRequirement = true
        ..meetsDigitsRequirement = true;

      final updated = sut.copyWith(
        meetsMinPasswordLength: false,
        meetsDigitsRequirement: false,
      );

      expect(updated.meetsMinPasswordLength, isFalse);
      expect(updated.meetsDigitsRequirement, isFalse);
      expect(updated.meetsMaxPasswordLength, isTrue);
      expect(updated.meetsLowercaseRequirement, isTrue);
      expect(updated.meetsUppercaseRequirement, isTrue);
    });

    test('mutates and returns the receiver rather than copying', () {
      // The extension cascades onto `this`; callers relying on the original
      // being untouched would be surprised, so the contract is pinned here.
      final sut = status();
      final updated = sut.copyWith(meetsUppercaseRequirement: false);

      expect(identical(updated, sut), isTrue);
      expect(sut.meetsUppercaseRequirement, isFalse);
    });

    test('with no arguments leaves every flag as it was', () {
      final sut = status()
        ..meetsMinPasswordLength = false
        ..meetsLowercaseRequirement = false;

      final updated = sut.copyWith();

      expect(updated.meetsMinPasswordLength, isFalse);
      expect(updated.meetsLowercaseRequirement, isFalse);
      expect(updated.meetsMaxPasswordLength, isTrue);
      expect(updated.meetsUppercaseRequirement, isTrue);
      expect(updated.meetsDigitsRequirement, isTrue);
    });
  });

  group('PasswordRequirementsNotMet', () {
    test('is an Exception carrying the failed status', () {
      final failed = status(minLength: 8)..meetsMinPasswordLength = false;
      final sut = PasswordRequirementsNotMet(status: failed);

      expect(sut, isA<Exception>());
      expect(identical(sut.status, failed), isTrue);
    });
  });
}
