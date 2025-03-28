part of 'exercises.dart';

class _OddState extends StatelessWidget {
  final String title;
  final String body;

  const _OddState({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        spacing: 32,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          Text(
            body,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final L(emptyExerciseHistoryTitle: title, emptyExerciseHistoryBody: body) = L.of(context);
    return _OddState(title: title, body: body);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    final L(errorExerciseHistoryTitle: title, errorExerciseHistoryBody: body) = L.of(context);
    return _OddState(title: title, body: body);
  }
}
