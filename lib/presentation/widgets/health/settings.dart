import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/health/permissions.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

/// The health block on the settings page.
///
/// Four jobs, and the last two are the reason it exists: say exactly what Heart
/// reads, restate where it is kept, give a route into the permission the app
/// cannot itself report on, and let the user throw the local copy away.
///
/// It is also the only way back for someone who dismissed the invitation on the
/// dashboard — that card is deliberately gone for good once waved away, so
/// without this the feature would be unreachable.
class const HealthSettings({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final health = Health.watch(context);
    final settings = Preferences.watch(context);
    final l = L.of(context);

    // No store on this platform, so there is nothing to explain, permit or
    // delete. Same reasoning as the dashboard section: absent beats empty.
    if (!health.isSupported || health.status != HealthStoreStatus.available) {
      return const SizedBox.shrink();
    }

    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final asked = settings.healthAsked(health.userId);

    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(l.health, style: textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(
            l.healthSettingsBody,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        // Before the sheet has ever been shown, the OS has nothing to show
        // either — Heart does not appear under the system's health permissions
        // until it has asked once. So the first tap asks; every later one is a
        // trip to where those permissions live, which is not this app's page in
        // the OS settings — see [openHealthPermissions].
        switch (asked) {
          false => ListTile(
            leading: const Icon(Icons.favorite_border_rounded),
            title: Text(l.healthInviteAction),
            onTap: () async {
              await health.connect();
              if (context.mounted) Preferences.of(context).setHealthAsked(health.userId);
            },
          ),
          true => ListTile(
            leading: const Icon(Icons.favorite_border_rounded),
            title: Text(healthPermissionsLabel(l)),
            subtitle: switch (healthPermissionsHint(l)) {
              String hint => Text(hint),
              null => null,
            },
            onTap: () => openHealthPermissions(health),
          ),
        },
        // Nothing read means nothing stored, and an enabled delete that clears
        // nothing is a button that lies about having done something.
        if (health.hasData)
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            title: Text(l.healthDelete, style: TextStyle(color: colorScheme.error)),
            onTap: () => _confirmDelete(context, health, l),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Health health, L l) async {
    final ThemeData(:colorScheme) = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await showBrandedDialog(
      context,
      title: Text(l.healthDeleteTitle, textAlign: .center),
      content: Text(l.healthDeleteBody, textAlign: .center),
      icon: Icon(Icons.error_outline_rounded, color: colorScheme.onErrorContainer),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Center(child: Text(l.cancel)),
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await health.forget();
                messenger.showSnackBar(SnackBar(content: Text(l.deleted)));
              },
              child: Center(child: Text(l.deleteThis)),
            ),
          ],
        ),
      ],
    );
  }
}
