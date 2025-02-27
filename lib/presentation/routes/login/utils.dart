part of 'login.dart';

String _errorCopy(L l, AuthExceptionReason reason) {
  return switch (reason) {
    AuthExceptionReason.invalidEmail => l.invalidCredentials,
    AuthExceptionReason.wrongPassword => l.invalidCredentials,
    AuthExceptionReason.userNotFound => l.invalidCredentials,
    AuthExceptionReason.userDisabled => l.userDisabled,
    AuthExceptionReason.unknown => l.unknownError,
  };
}
