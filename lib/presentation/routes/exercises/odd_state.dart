part of 'exercises.dart';

class _OddState extends StatelessWidget {
  final String title;
  final String body;

  const new({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);

    return Padding(
      padding: const .all(32.0),
      child: Center(
        // prose stops being readable long before a tablet pane runs out of
        // width, so the copy is capped rather than set to the space available
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: Column(
            spacing: 32,
            mainAxisAlignment: .center,
            children: [
              Text(
                title,
                style: textTheme.titleLarge,
                textAlign: .center,
              ),
              Text(
                body,
                style: textTheme.bodyLarge,
                textAlign: .center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final L(emptyExerciseHistoryTitle: title, emptyExerciseHistoryBody: body) = L.of(context);
    return _OddState(title: title, body: body);
  }
}

/// Holds the detail pane open on a wide screen before anything is picked.
///
/// The pane used to collapse instead, which let the list reflow from full width
/// to two fifths the moment you tapped a row.
class _NoSelectionState extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final L(noExerciseSelectedTitle: title, noExerciseSelectedBody: body) = L.of(context);
    return _OddState(key: AppKeys.noSelection, title: title, body: body);
  }
}

class _ErrorState extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final L(errorExerciseHistoryTitle: title, errorExerciseHistoryBody: body) = L.of(context);
    return _OddState(title: title, body: body);
  }
}
