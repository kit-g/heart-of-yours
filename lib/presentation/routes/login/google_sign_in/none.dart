import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const new({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    throw UnsupportedError('GoogleSignInButton is not supported on this platform.');
  }
}
