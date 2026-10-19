part of 'workout_detail.dart';

/// The one ask for workout sounds (#169, `docs/opt-in.md`), where it would
/// have done something: under the exercise whose rest first ran out with the
/// app on screen ([WorkoutSounds.offerUnder]). The countdown has just closed
/// on its own and the next set is still one tap away; a card under the list
/// asks without stopping anything.
///
/// Off, unanswered or declined, it is nothing, and the sheet is what it was
/// before the feature existed. A no leaves the one notice in the same place
/// for the rest of the session.
class const _SoundsOffer({required final WorkoutExercise exercise}) extends StatelessWidget {
  static const _feature = Feature.workoutSounds;

  @override
  Widget build(BuildContext context) {
    if (WorkoutSounds.watch(context).offerUnder != exercise.id) return const SizedBox.shrink();
    final preferences = Preferences.watch(context);
    final offers = preferences.shouldOffer(_feature);
    final owesNotice = preferences.owesDeclineNotice(_feature);
    if (!offers && !owesNotice) return const SizedBox.shrink();

    final L(:workoutSoundsOfferTitle, :workoutSoundsOfferBody) = L.of(context);
    return Padding(
      padding: const .fromLTRB(8, 4, 8, 12),
      child: switch (owesNotice) {
        true => FeatureDeclinedNotice(onDismiss: () => preferences.acknowledgeDeclineNotice(_feature)),
        false => FeatureOffer(
          key: WorkoutDetailKeys.soundsOffer,
          acceptKey: WorkoutDetailKeys.soundsAccept,
          declineKey: WorkoutDetailKeys.soundsDecline,
          icon: _feature.icon,
          title: workoutSoundsOfferTitle,
          body: workoutSoundsOfferBody,
          onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
          onShown: () => preferences.markOffered(_feature),
        ),
      },
    );
  }
}
