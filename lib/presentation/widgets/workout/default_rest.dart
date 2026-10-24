part of 'workout_detail.dart';

/// The one ask for default rest (#174, `docs/opt-in.md`), where it would have
/// done something: under the first exercise in the workout with a set ticked
/// and no rest to start for it. A tick that started nothing is the moment the
/// gap shows, and a card under the list asks without stopping anything —
/// the next set is still one tap away.
///
/// Off, unanswered or declined, every slot is empty and the sheet is what it
/// was before the feature existed. A no leaves the one notice in the same
/// place for the rest of the session.
class const _DefaultRestOffer({required final WorkoutExercise exercise}) extends StatelessWidget {
  static const _feature = Feature.defaultRest;

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final offers = preferences.shouldOffer(_feature);
    final owesNotice = preferences.owesDeclineNotice(_feature);
    if (!offers && !owesNotice) return const SizedBox.shrink();

    // a tick elsewhere, or a timer set on this exercise, moves the slot
    final workout = Workouts.watch(context).activeWorkout;
    Timers.watch(context);
    final anchor = workout
        ?.where((each) => each.any((set) => set.isCompleted) && restFor(context, each) == null)
        .firstOrNull;
    if (anchor?.id != exercise.id) return const SizedBox.shrink();

    final L(:defaultRestOfferTitle, :defaultRestOfferBody) = L.of(context);
    return Padding(
      padding: const .fromLTRB(8, 4, 8, 12),
      child: switch (owesNotice) {
        true => FeatureDeclinedNotice(onDismiss: () => preferences.acknowledgeDeclineNotice(_feature)),
        false => FeatureOffer(
          key: WorkoutDetailKeys.defaultRestOffer,
          acceptKey: WorkoutDetailKeys.defaultRestAccept,
          declineKey: WorkoutDetailKeys.defaultRestDecline,
          icon: _feature.icon,
          title: defaultRestOfferTitle,
          body: defaultRestOfferBody,
          onAnswer: (yes) => _answer(context, preferences, yes: yes),
          onShown: () => preferences.markOffered(_feature),
        ),
      },
    );
  }

  Future<void> _answer(BuildContext context, Preferences preferences, {required bool yes}) async {
    final platform = Theme.of(context).platform;
    final analytics = Analytics.of(context);
    final L(:notificationsDisabledReminder, :settings) = L.of(context);
    preferences.answerOffer(_feature, yes: yes);
    if (!yes) return;
    // the OS asks after our yes, never before it: a rest that ends unheard
    // with the phone in a pocket is half a rest timer
    final enabled = await ensureNotificationPermission(platform, analytics: analytics);
    if (enabled || !context.mounted) return;
    remindNotificationsOff(context, message: notificationsDisabledReminder, settingsLabel: settings);
  }
}
