part of 'login.dart';

String _errorCopy(L l, AuthExceptionReason reason) {
  return switch (reason) {
    .invalidEmail => l.invalidCredentials,
    .wrongPassword => l.invalidCredentials,
    .userNotFound => l.invalidCredentials,
    .userDisabled => l.userDisabled,
    .unknown => l.unknownError,
    .emailInUse => l.unknownError,
    .weakPassword => l.weakPassword,
    .networkRequestFailed => l.noConnectivity,
  };
}

bool _isApple(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS => true,
    TargetPlatform.macOS => true,
    _ => false,
  };
}

mixin AsyncState<T extends StatefulWidget> on State<T>, LoadingState<T>, HasError<T>, HasHaptic<T> {
  Future<void> run(AsyncCallback callback, {AsyncCallback? onEmailExists}) async {
    buzz();
    error.value = null;
    final l = L.of(context);

    try {
      startLoading();
      await callback();
    } on AuthException catch (e) {
      switch (e.reason) {
        case .emailInUse:
          return onEmailExists?.call();
        default:
          error.value = _errorCopy(l, e.reason);
          return;
      }
    } catch (error, stacktrace) {
      return reportToSentry(error, stacktrace: stacktrace);
    } finally {
      try {
        stopLoading();
      } catch (_) {
        //
      }
    }
  }
}
