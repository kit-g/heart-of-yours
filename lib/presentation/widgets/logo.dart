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
