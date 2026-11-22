import 'package:heart/core/utils/visual.dart' show showBrandedDialog;
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:material_ui/material_ui.dart';

/// Asks before something that can't be undone: [cancel] and [confirm], the
/// latter in the error colour under [key]. Answers whether it was confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  required Key key,
}) async {
  final sure = await showBrandedDialog<bool>(
    context,
    title: Text(title),
    content: Text(body),
    actions: [
      QuietButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        child: Text(cancel),
      ),
      QuietButton(
        key: key,
        danger: true,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        child: Text(confirm),
      ),
    ],
  );
  return sure ?? false;
}
