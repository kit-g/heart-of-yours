import 'package:flutter/material.dart';
import 'package:heart/core/utils/icons.dart';
import 'package:heart/presentation/widgets/buttons.dart';

/// The Google button everywhere that is not the web: our own control, with
/// Google's mark on it.
///
/// The web build gets Google's *rendered* button instead — see `web.dart` —
/// because Google ships one there and asks that it be used. There is no
/// equivalent on iOS or Android, so this is the compliant shape on those.
class GoogleSignInButton extends StatelessWidget {
  /// Copy, so it differs between signing in and signing up. The web button
  /// draws its own and ignores this.
  final String label;
  final VoidCallback? onPressed;

  const new({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderButton(
      icon: CustomIcons.google,
      label: label,
      onPressed: onPressed,
    );
  }
}
