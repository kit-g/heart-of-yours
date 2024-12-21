import 'package:flutter/material.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final L(:settings, :appearance) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Stack(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(settings),
                const SizedBox(width: 8),
                const Icon(Icons.settings),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            Text(
              appearance,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const _ThemeModePicker(),
          ],
        ),
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context) {
    final L(:toDarkMode, :toLightMode, :toSystemMode) = L.of(context);
    return Consumer<AppTheme>(
      builder: (__, appTheme, _) {
        final isSelected = ThemeMode.values.map((mode) => mode == appTheme.mode).toList();
        const radius = 4.0;
        return SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) {
              return ToggleButtons(
                constraints: BoxConstraints.expand(
                  width: (box.maxWidth - radius) / 3,
                ),
                borderRadius: BorderRadius.circular(radius),
                isSelected: isSelected,
                onPressed: (index) => _onPressed(index, appTheme),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_suggest),
                        const SizedBox(width: 4),
                        Text(toSystemMode),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.wb_sunny),
                        const SizedBox(width: 4),
                        Text(toLightMode),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.nights_stay),
                        const SizedBox(width: 4),
                        Text(toDarkMode),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _onPressed(int index, AppTheme appTheme) {
    return switch (index) {
      0 => appTheme.toSystem(),
      1 => appTheme.toLight(),
      2 => appTheme.toDark(),
      _ => () {},
    };
  }
}
