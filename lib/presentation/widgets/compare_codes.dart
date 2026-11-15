import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:heart/core/utils/visual.dart' show dialogWidth;
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// A device's name as screens show it: the end of its id, which is random,
/// where its start is the time it was made and alike between devices made
/// days apart.
String deviceName(L l, String id) {
  final hex = id.replaceAll('-', '').toUpperCase();
  return l.deviceName(hex.substring(hex.length < 6 ? 0 : hex.length - 6));
}

/// The comparison whose sheet is up, whichever screen opened it, or null:
/// there is only ever one, and whoever waits for it to close can tell.
final _sheet = ValueNotifier<String?>(null);

ValueListenable<String?> get comparisonSheet => _sheet;

/// Says [id]'s sheet is gone, unless another took its place meanwhile.
void _closed(String id) {
  if (_sheet.value == id) _sheet.value = null;
}

/// Shows the comparison [id] of a code with another of the account's devices
/// (#555), as [approval] has it, until it is closed. Closed while it runs,
/// that comparison ends on both devices: walking away from it is saying no.
/// One that came after it is never touched.
///
/// Shows nothing while another sheet is up.
Future<void> showCodeComparison(BuildContext context, DeviceApproval approval, String id) async {
  if (_sheet.value != null) return;
  _sheet.value = id;
  try {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: dialogWidth),
      builder: (_) => _ComparisonSheet(approval: approval, id: id),
    );
  } finally {
    _closed(id);
  }
  // each a no-op unless [id] is still the one there
  switch (approval.value?.running) {
    case true:
      await approval.deny(id: id);
    case false:
      approval.dismiss(id: id);
    case null:
      break;
  }
}

class _ComparisonSheet extends StatefulWidget {
  final DeviceApproval approval;
  final String id;

  const new({required this.approval, required this.id});

  @override
  State<_ComparisonSheet> createState() => _ComparisonSheetState();
}

class _ComparisonSheetState extends State<_ComparisonSheet> {
  /// The comparison this sheet was opened for, as it last stood: another
  /// that begins after it ended is not this sheet's to show.
  late final _shown = ValueNotifier(_mine());

  @override
  void initState() {
    super.initState();
    widget.approval.addListener(_follow);
  }

  @override
  void dispose() {
    widget.approval.removeListener(_follow);
    _shown.dispose();
    // gone with its route, closed or not, as when the app is torn down
    _closed(widget.id);
    super.dispose();
  }

  CodeComparison? _mine() {
    return switch (widget.approval.value) {
      final CodeComparison comparison when comparison.id == widget.id => comparison,
      _ => null,
    };
  }

  void _follow() {
    if (_mine() case final CodeComparison comparison) _shown.value = comparison;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const .fromLTRB(24, 24, 24, 16),
        child: ValueListenableBuilder<CodeComparison?>(
          valueListenable: _shown,
          builder: (context, comparison, _) {
            return Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              spacing: 16,
              children: [
                Semantics(
                  header: true,
                  child: Text(l.compareCodes, style: textTheme.titleLarge, textAlign: .center),
                ),
                ...switch (comparison) {
                  final CodeComparison comparison => _body(context, l, comparison),
                  null => const <Widget>[],
                },
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, L l, CodeComparison comparison) {
    final ThemeData(:textTheme) = Theme.of(context);
    final close = Align(
      child: PrimaryButton.shrunk(
        key: AppKeys.closeComparison,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l.close),
      ),
    );
    return switch (comparison.phase) {
      ComparisonWaiting() => [
        Text(
          switch (comparison.role) {
            .initiator => l.compareCodesWaiting,
            .responder => l.compareCodesAsked(deviceName(l, comparison.deviceId)),
          },
          textAlign: .center,
        ),
        const Center(child: CircularProgressIndicator()),
        Align(
          child: OutlinedButton(
            key: AppKeys.codesDontMatch,
            onPressed: () => widget.approval.deny(id: widget.id),
            child: Text(l.cancel),
          ),
        ),
      ],
      ComparisonCode(:final decimals) => [
        Text(l.compareCodesCheck, textAlign: .center),
        Text(
          decimals.join('   '),
          textAlign: .center,
          style: textTheme.displaySmall?.copyWith(fontFeatures: const [.tabularFigures()]),
        ),
        ...switch (comparison.confirmed) {
          true => [
            Text(l.compareCodesConfirmed, textAlign: .center),
            const Center(child: CircularProgressIndicator()),
          ],
          false => [
            Wrap(
              alignment: .center,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  key: AppKeys.codesDontMatch,
                  onPressed: () => widget.approval.deny(id: widget.id),
                  child: Text(l.codesDontMatch),
                ),
                PrimaryButton.shrunk(
                  key: AppKeys.codesMatch,
                  onPressed: widget.approval.confirm,
                  child: Text(l.codesMatch),
                ),
              ],
            ),
          ],
        },
      ],
      ComparisonDone() => [Text(l.compareCodesDone, textAlign: .center), close],
      ComparisonFailed(:final reason) => [
        Text(
          switch (reason) {
            .commitment || .keys => l.compareCodesTampered,
            .unreachable || .timeout => l.compareCodesNoAnswer,
            .unconfirmed => l.compareCodesUnconfirmed,
            .vouch => l.compareCodesVouchOwed,
          },
          textAlign: .center,
        ),
        close,
      ],
      ComparisonCancelled() => [Text(l.compareCodesCancelled, textAlign: .center), close],
    };
  }
}
