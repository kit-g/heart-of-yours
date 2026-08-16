import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

/// Where "let me review what Heart can read" goes, and what the control
/// offering it says.
///
/// The two live together because they have to agree, and because they were
/// wrong together: the button said "Open settings" and went to Settings › Heart,
/// which on iOS lists cellular data, Siri and search and nothing about health at
/// all. A user who taps it lands somewhere with no toggle to find and no reason
/// to think they are in the wrong place.

/// Label for the control that sends the user to the platform's health
/// permissions. Names the destination, because on iOS it is not the one a
/// "settings" button implies.
String healthPermissionsLabel(L l) {
  return switch (defaultTargetPlatform) {
    .iOS => l.healthOpenHealthApp,
    _ => l.healthOpenSettings,
  };
}

/// The step still left to the user once they are there.
///
/// Different step on each platform, and neither is signposted from where the
/// button lands. On iOS, Heart's row is two taps into the Health app and Apple
/// publishes no deep link to it. On Android the row is easy enough to find, but
/// past-data access is a separate switch kept away from the permission list —
/// so a user who grants everything they can see is still capped at 30 days.
String? healthPermissionsHint(L l) {
  return switch (defaultTargetPlatform) {
    .iOS => l.healthOpenHealthAppHint,
    _ => l.healthOpenSettingsHint,
  };
}

/// Why a dormant health section is dormant: the permission is not Heart's to
/// grant, and not in Heart's settings either.
///
/// Deliberately does not narrate the taps inside the destination. Written down,
/// that path is a guess about someone else's app across OS versions, and a
/// wrong one is worse than none — it sends a user somewhere real and tells them
/// they are lost. [showHealthOffDialog] does the navigating instead.
String healthOffExplanation(L l) {
  return switch (defaultTargetPlatform) {
    .iOS => l.healthOffInHealthApp,
    _ => l.healthOffInSettings,
  };
}

/// Explains the dormant section, and offers the trip out of it.
///
/// A dialog rather than a tooltip because the explanation is close to useless
/// without the button: knowing the permission lives in another app does not get
/// anybody there, and a tooltip cannot carry a control.
Future<void> showHealthOffDialog(BuildContext context, Health health, L l) {
  final ThemeData(:colorScheme) = Theme.of(context);

  return showBrandedDialog(
    context,
    title: Text(l.healthOffTitle, textAlign: .center),
    content: Text(healthOffExplanation(l), textAlign: .center),
    icon: const Icon(Icons.favorite_border_rounded),
    actions: [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              openHealthPermissions(health);
            },
            child: Center(child: Text(healthPermissionsLabel(l))),
          ),
          PrimaryButton.wide(
            backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Center(child: Text(l.cancel)),
          ),
        ],
      ),
    ],
  );
}

/// Sends the user to the platform's health permissions.
///
/// Falls back to the app's settings page only when the platform has nowhere
/// better — on Android that is at least the right building.
Future<void> openHealthPermissions(Health health) async {
  if (await health.openPermissions()) return;
  await AppSettings.openAppSettings(asAnotherTask: true);
}
