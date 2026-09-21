import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart';
import 'package:heart_state/heart_state.dart';

class GoogleSignInButton extends StatelessWidget {
  /// Accepted for one signature across the three platforms, and unused here:
  /// Google's own button carries its own copy, in the viewer's language.
  final String label;

  final VoidCallback? onPressed;

  const new({
    super.key,
    required this.label,
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
