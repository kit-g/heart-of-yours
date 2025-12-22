import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart';
import 'package:heart_state/heart_state.dart';

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
        return switch (future.connectionState) {
          .none => const SizedBox.shrink(),
          .active || .waiting => const SizedBox(
            width: 28,
            height: 28,
          ),
          .done => renderButton(
            configuration: GSIButtonConfiguration(
              type: .icon,
              shape: .pill,
              theme: .outline,
              size: .large,
            ),
          ),
        };
      },
    );
  }
}
