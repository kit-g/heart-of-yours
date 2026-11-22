import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:heart/core/utils/visual.dart' show dialogWidth, lineWidth;
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

/// Shows the comparison [opened] of a code with another of the account's devices
/// (#555), as [approval] has it, until it is closed. Closed while it runs,
/// that comparison ends on both devices: walking away from it is saying no.
/// One that came after it is never touched.
///
/// Shows nothing while another sheet is up.
Future<void> showCodeComparison(BuildContext context, DeviceApproval approval, String opened) async {
  if (_sheet.value != null) return;
  _sheet.value = opened;
  try {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: dialogWidth),
      builder: (_) => _ComparisonSheet(approval: approval, id: opened),
    );
  } finally {
    _closed(opened);
  }
  // the one the sheet ended on: the one it opened for, or the one both
  // devices kept when they asked each other
  final last = switch (approval.value) {
    CodeComparison(:final id, replaced: final String replaced) when replaced == opened => id,
    _ => opened,
  };
  // each a no-op unless it is still the one there
  switch (approval.value?.running) {
    case true:
      await approval.deny(id: last);
    case false:
      approval.dismiss(id: last);
    case null:
      break;
  }
}

/// The code, as large as fits the sheet on one line, because it is read and
/// compared as one row: at the type scale's 48pt it took two lines on every
/// phone. It grows with the reader's text size as far as the row allows, and
/// shrinks no further than its floor at that size; only past the floor does
/// it wrap, between groups, never inside one.
class _Code extends StatelessWidget {
  final List<int> decimals;

  const new(this.decimals);

  /// Below this, at the reader's text size, the code stops reading as the
  /// thing to compare.
  static const _smallest = 24.0;

  /// Room left over, so a size computed to fit exactly still fits once the
  /// glyphs are rounded.
  static const _slack = 2.0;

  @override
  Widget build(BuildContext context) {
    final code = decimals.join('   ');
    final display = Theme.of(context).textTheme.displaySmall;
    final full = display?.fontSize ?? _smallest;
    final style = (display ?? const TextStyle()).copyWith(fontSize: full, fontFeatures: const [.tabularFigures()]);
    // a face's advance grows in step with its size: one measure serves every
    // width the sheet can have
    final perPoint = lineWidth(context, code, style: style, textScaler: .noScaling) / full;
    final scaler = MediaQuery.textScalerOf(context);
    final wanted = scaler.scale(full);
    final floor = math.min(scaler.scale(_smallest), wanted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = (constraints.maxWidth - _slack) / perPoint;
        return Text(
          code,
          textAlign: .center,
          // scaled here already, where the fit can account for it
          textScaler: .noScaling,
          style: style.copyWith(fontSize: fits.clamp(floor, wanted)),
        );
      },
    );
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
      final CodeComparison comparison when comparison.id == widget.id || comparison.replaced == widget.id => comparison,
      _ => null,
    };
  }

  void _follow() {
    switch ((_mine(), _shown.value)) {
      case (final CodeComparison comparison, _):
        _shown.value = comparison;
      // abandoned under the sheet, as when the keys stop: it can no longer be
      // answered, and an answer must never reach whatever runs next
      case (null, final CodeComparison shown) when shown.running:
        _shown.value = CodeComparison(
          id: shown.id,
          deviceId: shown.deviceId,
          role: shown.role,
          phase: const ComparisonCancelled(),
        );
      case (null, _):
        break;
    }
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
    final ThemeData(:colorScheme) = Theme.of(context);
    final close = PrimaryButton.wide(
      key: AppKeys.closeComparison,
      margin: tallButtonPadding,
      onPressed: () => Navigator.of(context).pop(),
      child: Center(child: Text(l.close, textAlign: .center)),
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
        PrimaryButton.wide(
          key: AppKeys.codesDontMatch,
          backgroundColor: colorScheme.surfaceContainerHighest,
          margin: tallButtonPadding,
          onPressed: () => widget.approval.deny(id: comparison.id),
          child: Center(
            child: Text(
              l.cancel,
              textAlign: .center,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
        ),
      ],
      ComparisonCode(:final decimals) => [
        Text(l.compareCodesCheck, textAlign: .center),
        _Code(decimals),
        ...switch (comparison.confirmed) {
          true => [
            Text(l.compareCodesConfirmed, textAlign: .center),
            const Center(child: CircularProgressIndicator()),
          ],
          false => [
            ButtonPair(
              cancel: l.codesDontMatch,
              cancelKey: AppKeys.codesDontMatch,
              onCancel: () => widget.approval.deny(id: comparison.id),
              action: l.codesMatch,
              actionKey: AppKeys.codesMatch,
              onAction: () => widget.approval.confirm(id: comparison.id),
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
