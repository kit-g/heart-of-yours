part of 'done.dart';

/// The session's muscle map, on request (#223). The screen is a moment, and
/// OK is what it asks for, so the map waits under it behind a quiet button:
/// there for whoever wants more once the confetti settles, and never in the
/// way of whoever doesn't. Nothing at all when the map has nothing to show.
class _MusclesWorked extends StatefulWidget {
  final Workout workout;

  const new({required this.workout});

  @override
  State<_MusclesWorked> createState() => _MusclesWorkedState();
}

class _MusclesWorkedState extends State<_MusclesWorked> {
  final _open = ValueNotifier(false);
  final _map = GlobalKey();

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _reveal() {
    _open.value = true;
    // it opens below the fold on a phone: bring it up once it has a size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_map.currentContext case BuildContext context when context.mounted) {
        Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Preferences.watch(context);
    if (!WorkoutMuscleMap.shows(context, widget.workout)) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: _open,
      builder: (_, open, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: .topCenter,
          child: switch (open) {
            false => Padding(
              padding: const .only(top: 8),
              child: TextButton.icon(
                key: AppKeys.musclesWorkedButton,
                onPressed: _reveal,
                icon: const Icon(Icons.accessibility_new_rounded),
                label: Text(L.of(context).musclesWorked),
              ),
            ),
            true => WorkoutMuscleMap(
              key: _map,
              workout: widget.workout,
              padding: const .fromLTRB(16, 24, 16, 16),
            ),
          },
        );
      },
    );
  }
}
