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

/// Shows the comparison of a code with another of the account's devices
/// (#555), as [approval] has it, until it is closed. Closed while it runs,
/// it ends on both devices: walking away from it is saying no.
Future<void> showCodeComparison(BuildContext context, DeviceApproval approval) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (_) => _ComparisonSheet(approval: approval),
  );
  switch (approval.value?.running) {
    case true:
      await approval.deny();
    case false:
      approval.dismiss();
    case null:
      break;
  }
}

class const _ComparisonSheet({required final DeviceApproval approval}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const .fromLTRB(24, 24, 24, 16),
        child: ValueListenableBuilder<CodeComparison?>(
          valueListenable: approval,
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
            onPressed: approval.deny,
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
                  onPressed: approval.deny,
                  child: Text(l.codesDontMatch),
                ),
                PrimaryButton.shrunk(
                  key: AppKeys.codesMatch,
                  onPressed: approval.confirm,
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
          },
          textAlign: .center,
        ),
        close,
      ],
      ComparisonCancelled() => [Text(l.compareCodesCancelled, textAlign: .center), close],
    };
  }
}
