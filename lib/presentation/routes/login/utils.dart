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

bool _isApple(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS => true,
    TargetPlatform.macOS => true,
    _ => false,
  };
}

mixin AsyncState<T extends StatefulWidget> on State<T>, LoadingState<T>, HasError<T> {
  Future<void> run(AsyncCallback callback) async {
    error.value = null;
    final l = L.of(context);

    try {
      startLoading();
      await callback();
    } on AuthException catch (e) {
      error.value = _errorCopy(l, e.reason);
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
    } finally {
      try {
        stopLoading();
      } catch (_) {
        //
      }
    }
  }
}
