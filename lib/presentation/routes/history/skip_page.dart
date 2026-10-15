part of 'history.dart';

/// A day set aside with "Not today" (#312), on a page of its own: what a
/// calendar event's link opens when its session was skipped (#391), and what a
/// skip's row in History opens. The session, its program and the day, and the
/// way on to the program.
class SkipPage extends StatelessWidget {
  final String skipId;
  final ValueChanged<String> onOpenProgram;

  /// Empties the two-pane detail. Null in compact, where the page is pushed and
  /// popping it is the right thing.
  final VoidCallback? onClose;

  const new({super.key, required this.skipId, required this.onOpenProgram, this.onClose});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final programs = Programs.watch(context);
    final skip = programs.skips.where((skip) => skip.id == skipId).firstOrNull;
    final leading = switch (onClose) {
      final VoidCallback close => IconButton(
        key: AppKeys.closeDetail,
        tooltip: copy.close,
        onPressed: close,
        icon: const Icon(Icons.close),
      ),
      null => null,
    };
    // taken back, or not read yet; and with Programs off there are no skips
    if (skip == null || !Preferences.watch(context).isOn(.programs)) {
      return Scaffold(appBar: AppBar(leading: leading));
    }

    final session = switch (skip.templateId) {
      final String id => Templates.watch(context).lookup(id)?.name,
      null => null,
    };
    final program = switch (skip.programId) {
      final String id => programs.lookup(id),
      null => null,
    };
    final muted = textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(leading: leading, title: Text(copy.programNotToday)),
      body: SafeArea(
        child: Align(
          alignment: .topCenter,
          // a few lines of prose: a measure, not a tablet pane's width
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: readableWidth),
            child: ListView(
              key: AppKeys.skipPage,
              padding: const .all(16),
              children: [
                Row(
                  spacing: 12,
                  children: [
                    Icon(Icons.redo_rounded, color: colorScheme.outline),
                    Expanded(
                      child: Text(
                        session ?? copy.programNotToday,
                        style: textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(DateFormat.yMMMMEEEEd(copy.localeName).format(skip.at.toLocal()), style: muted),
                if (program case Program(:final name, :final String id)) ...[
                  const SizedBox(height: 4),
                  Text(name, style: muted),
                  const SizedBox(height: 24),
                  Align(
                    alignment: .centerLeft,
                    child: PrimaryButton.shrunk(
                      key: AppKeys.skipOpenProgram,
                      onPressed: () => onOpenProgram(id),
                      child: Text(copy.programOpen),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
