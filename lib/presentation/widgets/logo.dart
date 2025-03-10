import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';

class Logo extends StatelessWidget {
  final double titleFontSize;

  const Logo({
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

  const LogoTitle({
    super.key,
    this.fontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'Heart of yours',
      style: TextStyle(
        fontFamily: 'Daydream',
        fontSize: fontSize,
      ),
    );
  }
}

class Motto extends StatelessWidget {
  final double fontSize;

  const Motto({
    super.key,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      L.of(context).motto,
      style: TextStyle(
        fontFamily: 'Daydream',
        fontSize: fontSize,
      ),
    );
  }
}

class LogoStripe extends StatelessWidget {
  final Color? backgroundColor;

  const LogoStripe({super.key, this.backgroundColor});

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
