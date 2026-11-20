import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The one ask for an opt-in feature, in the place it would do something
/// (`docs/opt-in.md`). Showing it is what spends it: an offer the user scrolls
/// past and never answers is a no from the next launch on, so [onShown] runs
/// once, when it first goes on screen.
class FeatureOffer extends StatefulWidget {
  final IconData icon;
  final String title;
  final String body;
  final ValueChanged<bool> onAnswer;
  final VoidCallback onShown;
  final Key? acceptKey;
  final Key? declineKey;

  const new({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onAnswer,
    required this.onShown,
    this.acceptKey,
    this.declineKey,
  });

  @override
  State<FeatureOffer> createState() => _FeatureOfferState();
}

class _FeatureOfferState extends State<FeatureOffer> {
  @override
  void initState() {
    super.initState();
    widget.onShown();
  }

  @override
  Widget build(BuildContext context) {
    final L(:noThanks, :turnOn) = L.of(context);
    final ThemeData(:textTheme, :dividerColor) = Theme.of(context);

    return Align(
      alignment: .centerLeft,
      child: ConstrainedBox(
        // prose, so it gets a measure rather than an iPad's width
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Container(
          decoration: BoxDecoration(
            border: .all(color: dividerColor, width: .5),
            borderRadius: const .all(.circular(12)),
          ),
          padding: const .all(16),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              Row(
                spacing: 12,
                children: [
                  Icon(widget.icon),
                  Expanded(child: Text(widget.title, style: textTheme.titleMedium)),
                ],
              ),
              Text(widget.body, style: textTheme.bodyMedium),
              // stacked, still at the end, when the two don't fit one line:
              // Russian at a large text size on a phone (#701)
              OverflowBar(
                alignment: .end,
                overflowAlignment: .end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    key: widget.declineKey,
                    onPressed: () => widget.onAnswer(false),
                    child: Text(noThanks),
                  ),
                  PrimaryButton.shrunk(
                    key: widget.acceptKey,
                    onPressed: () => widget.onAnswer(true),
                    child: Text(turnOn),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single line a no earns: where the way back is. Gone once closed, and
/// gone with the session either way — it is never shown again.
class FeatureDeclinedNotice extends StatelessWidget {
  final VoidCallback onDismiss;

  const new({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final L(:featureDeclinedNotice, :close) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Align(
      alignment: .centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Row(
          key: AppKeys.featureDeclinedNotice,
          spacing: 8,
          children: [
            Icon(Icons.settings_outlined, size: 18, color: colorScheme.onSurfaceVariant),
            Expanded(
              child: Text(
                featureDeclinedNotice,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            // an IconButton for its 48pt target: the icon alone is 20
            IconButton(
              tooltip: close,
              onPressed: onDismiss,
              iconSize: 20,
              color: colorScheme.onSurfaceVariant,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one ask for [feature] as a sheet over whatever led to it — a menu
/// item, a calendar day — for a feature asked about on a tap rather than in a
/// list. Showing it spends the offer; dismissing it is waving it away, a no.
/// Completes with the answer, recorded ([answerOffer]) before it returns, so
/// an answer outlives a caller that went away while the sheet was up.
Future<bool> askInSheet(
  BuildContext context,
  Feature feature, {
  required IconData icon,
  required String title,
  required String body,
  Key? offerKey,
  Key? acceptKey,
  Key? declineKey,
}) async {
  final preferences = Preferences.of(context);
  final answer = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const .fromLTRB(16, 24, 16, 16),
          // the offer is laid out for a list, where it gets unbounded height;
          // in a sheet it would fill the sheet's height without this
          child: Column(
            mainAxisSize: .min,
            children: [
              FeatureOffer(
                key: offerKey,
                acceptKey: acceptKey,
                declineKey: declineKey,
                icon: icon,
                title: title,
                body: body,
                onAnswer: (yes) => Navigator.of(context).pop(yes),
                onShown: () => preferences.markOffered(feature),
              ),
            ],
          ),
        ),
      );
    },
  );
  final yes = answer ?? false;
  preferences.answerOffer(feature, yes: yes);
  if (!yes && context.mounted) {
    snack(context, L.of(context).featureDeclinedNotice);
    // the snack was the notice: owed once, and now paid
    preferences.acknowledgeDeclineNotice(feature);
  }
  return yes;
}
