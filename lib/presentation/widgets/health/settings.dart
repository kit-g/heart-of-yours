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

    // Colour as the closest thing to a "connected" light this feature is
    // allowed to have. iOS will not disclose read access, so the heart follows
    // [Health.hasData] — readings arriving is the only proof access exists.
    final heart = Icon(
      health.hasData ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: health.hasData ? colorScheme.primary : null,
    );

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
            leading: heart,
            title: Text(l.healthInviteAction),
            onTap: () async {
              await health.connect();
              if (context.mounted) Preferences.of(context).setHealthAsked(health.userId);
            },
          ),
          true => ListTile(
            leading: heart,
            title: Text(healthPermissionsLabel(l)),
            subtitle: switch (healthPermissionsHint(l)) {
              String hint => Text(hint),
              null => null,
            },
            onTap: () => openHealthPermissions(health),
          ),
        },
        // Write-back, and only once the user has engaged with health at all.
        // Before that, [connect] asks for the write alongside everything else,
        // so a second row here would be noise offering what the row above
        // already covers.
        //
        // It has to be reachable, though, and that is the whole point of it:
        // anyone who granted read access before Heart could write is never
        // asked by [connect] again, and the platform's own permission screen
        // lists only the types an app has requested — so without this row there
        // is no toggle for them to find anywhere. See
        // [Health.requestWorkoutWriteAccess].
        //
        // Two states, not three, because the platforms only report two: not
        // granted covers a refusal and never having been asked alike. So the
        // subtitle states the fact — it is off — rather than guessing at why,
        // and the tap tries the ask before falling back to the OS screen.
        if (asked)
          switch (health.workoutWriteAccess) {
            .granted => ListTile(
              leading: Icon(Icons.fitness_center_rounded, color: colorScheme.primary),
              title: Text(l.healthWriteWorkouts),
              subtitle: Text(l.healthWriteWorkoutsOn),
              // Turning it back off is the platform's to offer, not Heart's.
              onTap: () => openHealthPermissions(health),
            ),
            .denied || .unknown => ListTile(
              leading: const Icon(Icons.fitness_center_rounded),
              title: Text(l.healthWriteWorkouts),
              subtitle: Text(l.healthWriteWorkoutsOff),
              onTap: () => _enableWriting(health),
            ),
            // Not read yet, or no store to read it from.
            null => const SizedBox.shrink(),
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

  /// Turns write-back on, by whichever route this user still has.
  ///
  /// The ask first, because for anyone who has simply never been asked it is
  /// one tap and done. If the permission was already refused no sheet appears
  /// and nothing changes — and *that* is the case the fallback is for, since
  /// the only place a refusal can be reversed is the platform's own screen.
  Future<void> _enableWriting(Health health) async {
    if (await health.requestWorkoutWriteAccess() case .granted) return;
    await openHealthPermissions(health);
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
