import 'package:flutter/material.dart';
import 'package:heart/core/utils/assets.dart';
import 'package:heart/presentation/widgets/vector.dart';
import 'package:heart_language/heart_language.dart';

class UpgradeRequiredPage extends StatelessWidget {
  const UpgradeRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final L(:updateRequiredBody, :updateRequiredTitle, :updateRequiredCta) = L.of(context);
    final ThemeData(:textTheme, :platform, :colorScheme) = Theme.of(context);

    // keep untranslated
    final store = switch (platform) {
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
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Vector(
                    Assets.mobileUpgrade,
                    height: 64,
                    width: 64,
                    color: colorScheme.primary,
                  ),
                ),
              ),
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
