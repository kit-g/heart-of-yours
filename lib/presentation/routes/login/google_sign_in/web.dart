import 'package:flutter/material.dart';
import 'package:heart_state/heart_state.dart';
import 'package:google_sign_in_web/web_only.dart';

class GoogleSignInButton extends StatelessWidget {
  final void Function()? onPressed;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Auth.of(context).initGoogleSignIn(),
      builder: (_, future) {
        switch (future.connectionState) {
          case ConnectionState.none:
            return const SizedBox.shrink();
          case ConnectionState.active:
          case ConnectionState.waiting:
            return const SizedBox(
              width: 28,
              height: 28,
            );
          case ConnectionState.done:
            return renderButton(
              configuration: GSIButtonConfiguration(
                type: GSIButtonType.icon,
                shape: GSIButtonShape.pill,
                theme: GSIButtonTheme.outline,
                size: GSIButtonSize.large,
              ),
            );
        }
      },
    );
  }
}
