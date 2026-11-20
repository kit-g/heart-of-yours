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

/// The inset that makes the sheet's buttons full 48pt targets, as the import
/// page's pair is.
const EdgeInsets _answerInset = .symmetric(horizontal: 8, vertical: 14);

/// The code, as large as fits the sheet on one line at the reader's base text
/// size, because it is read and compared as one row: at the type scale's 48pt
/// it took two lines on every phone. Text scaling grows it from there and
/// wraps it between groups, never inside one.
class _Code extends StatelessWidget {
  final List<int> decimals;

  const new(this.decimals);

  /// Below this the code stops reading as the thing to compare.
  static const _smallest = 24.0;

  @override
  Widget build(BuildContext context) {
    final code = decimals.join('   ');
    final style = DefaultTextStyle.of(context).style.merge(
      Theme.of(context).textTheme.displaySmall?.copyWith(fontFeatures: const [.tabularFigures()]),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final full = style.fontSize ?? _smallest;
        final painter = TextPainter(
          text: TextSpan(text: code, style: style),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        // floored: a size that fits exactly can still wrap on rounding
        final fitted = switch (width <= constraints.maxWidth) {
          true => full,
          false => (full * constraints.maxWidth / width).floorToDouble(),
        };
        return Text(
          code,
          textAlign: .center,
          style: style.copyWith(fontSize: fitted < _smallest ? _smallest : fitted),
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
    final ThemeData(:colorScheme) = Theme.of(context);
    final close = PrimaryButton.wide(
      key: AppKeys.closeComparison,
      margin: _answerInset,
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
          margin: _answerInset,
          onPressed: () => widget.approval.deny(id: widget.id),
          child: Center(child: Text(l.cancel, textAlign: .center)),
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
            // the dialogs' pair laid flat, as on the import page: one row,
            // one size, the way out muted. Sized together, so a label that
            // wraps in a longer language grows both and they stay one choice
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: .stretch,
                spacing: 8,
                children: [
                  Expanded(
                    child: PrimaryButton.wide(
                      key: AppKeys.codesDontMatch,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      margin: _answerInset,
                      onPressed: () => widget.approval.deny(id: widget.id),
                      child: Center(child: Text(l.codesDontMatch, textAlign: .center)),
                    ),
                  ),
                  Expanded(
                    child: PrimaryButton.wide(
                      key: AppKeys.codesMatch,
                      margin: _answerInset,
                      onPressed: widget.approval.confirm,
                      child: Center(child: Text(l.codesMatch, textAlign: .center)),
                    ),
                  ),
                ],
              ),
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
