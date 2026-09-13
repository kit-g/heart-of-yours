import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';

class Logo extends StatelessWidget {
  final double titleFontSize;

  const new({
    super.key,
    this.titleFontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LogoTitle(),
        Motto(),
      ],
    );
  }
}

class LogoTitle extends StatelessWidget {
  final double fontSize;

  const new({
    super.key,
    this.fontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      // lowercase is the logotype, not the name: the app is still called
      // "Heart of yours" everywhere a name is read — the stores, the home
      // screen label, `APP_NAME`
      'heart of yours',
      style: TextStyle(
        // The wordmark does not follow the preset, and is deliberately not one
        // of the preset faces. It has to agree with the launcher icon and the
        // site, neither of which knows which preset a user picked — and a
        // logotype set in the UI's own face stops reading as a mark, which is
        // what Literata did on Ink.
        fontFamily: 'Space Grotesk',
        fontWeight: .w600,
        fontSize: fontSize,
        letterSpacing: fontSize * -0.015,
      ),
    );
  }
}

class Motto extends StatelessWidget {
  final double fontSize;
  final FontWeight? weight;

  const new({
    super.key,
    this.fontSize = 24,
    this.weight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      L.of(context).motto,
      // the motto is copy, not the mark: it wears whatever face the preset
      // dresses the rest of the app in
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
      ),
    );
  }
}

class LogoStripe extends StatelessWidget {
  final Color? backgroundColor;

  const new({super.key, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final color = backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: .2),
            color,
          ],
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LogoTitle(fontSize: 32),
            Motto(fontSize: 18),
          ],
        ),
      ),
    );
  }
}
