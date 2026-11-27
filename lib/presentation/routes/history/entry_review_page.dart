part of 'history.dart';

/// History's way to the list of suspicious entries (#428): there while the
/// feature is on and the server has flagged anything, pending or decided, with
/// a dot while one is still to look at. The dot is the most the feature ever
/// says on its own: never a notification.
class _EntryReviewButton extends StatelessWidget {
  final VoidCallback onPressed;

  const new({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final anomalies = Provider.of<Anomalies?>(context);
    if (anomalies == null || anomalies.isEmpty || !Preferences.watch(context).isOn(.entryReview)) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    final pending = anomalies.pending.length;
    const icon = Icon(Icons.flag_outlined);

    return IconButton(
      key: AppKeys.entryReviewButton,
      tooltip: pending == 0 ? l.entryReview : l.entryReviewPending(pending),
      onPressed: onPressed,
      icon: switch (pending) {
        0 => icon,
        _ => Badge(smallSize: 8, backgroundColor: Theme.of(context).colorScheme.tertiary, child: icon),
      },
    );
  }
}

/// The one ask for suspicious entries (`docs/opt-in.md`), at the top of
/// History the first time the server has flagged something still to decide:
/// the moment the feature would first have something to show. Then the one
/// notice a no earns, and after that nothing — the slot is empty and History is
/// as it was before the feature existed.
class _EntryReviewOffer extends StatelessWidget {
  static const _feature = Feature.entryReview;

  const new();

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final anomalies = Provider.of<Anomalies?>(context);
    final l = L.of(context);

    final Widget? child = switch (anomalies) {
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      final Anomalies anomalies when preferences.shouldOffer(_feature) && anomalies.pending.isNotEmpty => FeatureOffer(
        key: AppKeys.entryReviewOffer,
        acceptKey: AppKeys.entryReviewAccept,
        declineKey: AppKeys.entryReviewDecline,
        icon: _feature.icon,
        title: l.entryReviewOfferTitle,
        body: l.entryReviewOfferBody,
        onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
        onShown: () => preferences.markOffered(_feature),
      ),
      _ => null,
    };

    return switch (child) {
      final Widget child => Padding(padding: const .fromLTRB(16, 8, 16, 8), child: child),
      null => const SizedBox.shrink(),
    };
  }
}

/// Every suspicious entry the server found (#428), newest first: those still
/// to look at, then those decided. Each opens the same decision its mark on
/// the workout does, and the workout itself, where the entry can be changed.
/// Looked at, the list is read again: flags arrive late.
class EntryReviewPage extends StatefulWidget {
  final ValueChanged<String> onOpenWorkout;

  /// Empties the two-pane detail. Null in compact, where the page is pushed and
  /// popping it is the right thing.
  final VoidCallback? onClose;

  const new({super.key, required this.onOpenWorkout, this.onClose});

  @override
  State<EntryReviewPage> createState() => _EntryReviewPageState();
}

class _EntryReviewPageState extends State<EntryReviewPage> {
  @override
  void initState() {
    super.initState();
    Anomalies.of(context).pull();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :sectionHeader) = Theme.of(context);
    final anomalies = Anomalies.watch(context);
    final pending = anomalies.pending.toList();
    final decided = anomalies.where((each) => each.status != .pending).toList();

    Widget header(String title) {
      return Padding(
        padding: const .fromLTRB(16, 16, 16, 4),
        child: Text(title.toUpperCase(), style: sectionHeader),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.entryReview),
        leading: switch (widget.onClose) {
          final VoidCallback close => IconButton(
            key: AppKeys.closeDetail,
            tooltip: l.close,
            onPressed: close,
            icon: const Icon(Icons.close),
          ),
          null => null,
        },
      ),
      body: SafeArea(
        child: Align(
          alignment: .topCenter,
          // rows of a line or two: a measure, not a tablet pane's width
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: readableWidth),
            child: switch (anomalies.isEmpty) {
              true => Padding(
                padding: const .all(24),
                child: Text(
                  l.entryReviewEmpty,
                  textAlign: .center,
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
              false => ListView(
                key: AppKeys.entryReviewPage,
                padding: const .only(bottom: 24),
                children: [
                  if (pending.isNotEmpty) ...[
                    header(l.entryReviewToLookAt),
                    for (final anomaly in pending) _AnomalyRow(anomaly: anomaly, onOpenWorkout: widget.onOpenWorkout),
                  ],
                  if (decided.isNotEmpty) ...[
                    header(l.entryReviewDecided),
                    for (final anomaly in decided) _AnomalyRow(anomaly: anomaly, onOpenWorkout: widget.onOpenWorkout),
                  ],
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _AnomalyRow extends StatefulWidget {
  final Anomaly anomaly;
  final ValueChanged<String> onOpenWorkout;

  const new({required this.anomaly, required this.onOpenWorkout});

  @override
  State<_AnomalyRow> createState() => _AnomalyRowState();
}

class _AnomalyRowState extends State<_AnomalyRow> {
  final _anchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    final anomaly = widget.anomaly;
    final title = switch ((anomaly.setId, anomaly.exerciseName)) {
      (null, _) => l.entryReviewDuration,
      (_, final String name) => name,
      (_, null) => anomaly.short(l),
    };
    final (icon, status) = switch (anomaly.status) {
      .pending => (Icons.flag_outlined, anomaly.short(l)),
      .valid => (Icons.check_rounded, l.anomalyKept),
      .invalid => (Icons.remove_circle_outline_rounded, l.anomalyLeftOut),
    };
    final when = switch (anomaly.workoutStart) {
      final DateTime start => DateFormat.yMMMd(l.localeName).format(start.toLocal()),
      null => null,
    };

    return ListTile(
      key: AppKeys.anomalyRow(anomaly.id),
      leading: Icon(icon, color: colorScheme.onSurfaceVariant, key: _anchor),
      title: Text(title, maxLines: 1, overflow: .ellipsis),
      subtitle: Text([?when, status].join(' · '), maxLines: 1, overflow: .ellipsis),
      trailing: const Icon(Icons.more_horiz_rounded),
      onTap: () => showEntryDecision(
        context,
        anomaly,
        position: _anchor.position(),
        onOpenWorkout: () => widget.onOpenWorkout(anomaly.workoutId),
      ),
    );
  }
}
