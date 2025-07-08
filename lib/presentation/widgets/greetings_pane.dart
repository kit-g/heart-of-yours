import 'package:flutter/material.dart';
import 'package:heart/core/utils/assets.dart';

class GreetingsPane extends StatelessWidget {
  final String title;
  final String body;

  const GreetingsPane({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:primaryColor, :textTheme, :colorScheme) = Theme.of(context);

    return Container(
      color: primaryColor,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(Assets.logo),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: textTheme.displaySmall?.copyWith(color: colorScheme.onPrimary, fontFamily: 'Daydream'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    body,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
