import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final void Function()? onPressed;

  const new({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    throw UnsupportedError('GoogleSignInButton is not supported on this platform.');
  }
}
