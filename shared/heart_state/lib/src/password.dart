import 'package:firebase_auth/firebase_auth.dart' as fb;

typedef PasswordValidationStatus = fb.PasswordValidationStatus;

extension ExtendedPasswordValidationStatus on PasswordValidationStatus {
  PasswordValidationStatus copyWith({
    bool? meetsMinPasswordLength,
    bool? meetsMaxPasswordLength,
    bool? meetsLowercaseRequirement,
    bool? meetsUppercaseRequirement,
    bool? meetsDigitsRequirement,
  }) {
    return this
      ..meetsMinPasswordLength = meetsMinPasswordLength ?? this.meetsMinPasswordLength
      ..meetsMaxPasswordLength = meetsMaxPasswordLength ?? this.meetsMaxPasswordLength
      ..meetsLowercaseRequirement = meetsLowercaseRequirement ?? this.meetsLowercaseRequirement
      ..meetsUppercaseRequirement = meetsUppercaseRequirement ?? this.meetsUppercaseRequirement
      ..meetsDigitsRequirement = meetsDigitsRequirement ?? this.meetsDigitsRequirement;
  }

  bool satisfiesMaxPasswordLength(final String text) {
    return (passwordPolicy.maxPasswordLength ?? 120) >= text.length;
  }

  bool satisfiesMinPasswordLength(final String text) {
    return passwordPolicy.minPasswordLength <= text.length;
  }

  bool satisfiesDigitRequirement(final String text) {
    if (!(passwordPolicy.containsNumericCharacter ?? false)) return true;
    return text.contains(RegExp(r'[0-9]'));
  }

  bool satisfiesUpperCaseRequirement(final String text) {
    if (!(passwordPolicy.containsUppercaseCharacter ?? false)) return true;
    return text.contains(RegExp(r'[A-Z]'));
  }

  bool satisfiesLowerCaseRequirement(final String text) {
    if (!(passwordPolicy.containsLowercaseCharacter ?? false)) return true;
    return text.contains(RegExp(r'[a-z]'));
  }
}
