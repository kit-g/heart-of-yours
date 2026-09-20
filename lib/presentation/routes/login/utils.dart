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

/// "Sign in with Google" and its siblings: the provider's mark on the leading
/// edge, the label centred across the button.
///
/// It was an [OutlinedButton] with the label centred inside it and the mark
/// laid over the top by a `Positioned(left: 24)` in a [Stack]. Nothing
/// connected the two — the label was centred across the *whole* button,
/// including the strip the mark sat in — so as soon as the copy grew past the
/// English it ran underneath the mark. On a phone that is every language we
/// ship but English: "Iniciar sesión con Google" rendered as
/// "GIniciar sesión con Google", on the one screen App Review always walks.
///
/// So the mark is a child now rather than an overlay, and the label gets the
/// space that is left, with a gutter of the mark's own width opposite it so the
/// two still read as centred. Copy that outgrows the row is scaled down to fit
/// it instead of colliding with the mark.
class _ProviderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const _mark = 24.0;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: _mark),
          Expanded(
            child: Padding(
              padding: const .symmetric(horizontal: 8),
              // Scaled to one line rather than wrapped. A provider button is a
              // single control with a single label; broken over two lines it
              // stops matching the plain sign-in button above it and starts
              // reading as a paragraph. The shrink is small — Spanish is the
              // longest of the five and clears the row at a hair under full
              // size — and English never scales at all.
              child: FittedBox(
                fit: .scaleDown,
                child: Text(label),
              ),
            ),
          ),
          // balances the mark, so the label is centred on the button and not
          // merely on the room the mark leaves it
          const SizedBox(width: _mark),
        ],
      ),
    );
  }
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
    } catch (e, stacktrace) {
      error.value = l.unknownError;
      return reportToSentry(e, stacktrace: stacktrace);
    } finally {
      try {
        stopLoading();
      } catch (_) {
        //
      }
    }
  }
}
