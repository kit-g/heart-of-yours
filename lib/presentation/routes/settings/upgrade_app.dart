import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';

class UpgradeRequiredPage extends StatelessWidget {
  const UpgradeRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final L(:updateRequiredBody, :updateRequiredTitle, :updateRequiredCta) = L.of(context);
    final ThemeData(:textTheme, :platform) = Theme.of(context);

    final store = switch (platform) {
      // keep untranslated
      .android => 'Play Store',
      .iOS || .macOS => 'App Store',
      _ => null,
    };

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 64),
              const SizedBox(height: 24),
              Text(
                updateRequiredTitle,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                updateRequiredBody,
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (store != null)
                FilledButton(
                  onPressed: () {},
                  child: Text(updateRequiredCta(store)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
