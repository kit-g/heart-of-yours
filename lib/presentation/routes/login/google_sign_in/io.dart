import 'package:flutter/material.dart';
import 'package:heart/core/utils/icons.dart';
import 'package:heart_language/heart_language.dart';

class GoogleSignInButton extends StatelessWidget {
  final void Function()? onPressed;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final L(:logInWithGoogle) = L.of(context);
    return Stack(
      children: [
        const Positioned(
          top: 0,
          bottom: 0,
          left: 24,
          child: Icon(CustomIcons.google),
        ),
        OutlinedButton(
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(logInWithGoogle),
            ],
          ),
        ),
      ],
    );
  }
}
