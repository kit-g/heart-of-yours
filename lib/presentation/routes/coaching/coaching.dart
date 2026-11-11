/// The Coaching space (#168, #566): a coach's work in tabs of its own, apart
/// from their training. Clients, Messages, Programs and Me, behind one button
/// on Profile, while Coach people is on.
library;

import 'package:clock/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/avatar.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart/presentation/widgets/setting_picker.dart';
import 'package:heart/presentation/widgets/tab_frame.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

part 'activity.dart';
part 'clients.dart';
part 'frame.dart';
part 'invitation.dart';
part 'invite.dart';
part 'pages.dart';

/// Whether the Coaching space is there at all: Coach people is on, for an
/// account that may coach. Off for either reason, the app looks as if
/// coaching had never been built.
bool coachingSpaceOn(BuildContext context, {bool listen = false}) {
  final preferences = Provider.of<Preferences>(context, listen: listen);
  final auth = Provider.of<Auth>(context, listen: listen);
  return preferences.isOn(.coachPeople) && (auth.user?.mayCoach ?? false);
}
