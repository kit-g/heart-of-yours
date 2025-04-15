part of 'workout.dart';

class WorkoutPage extends StatefulWidget {
  final void Function({bool? newTemplate}) goToTemplateEditor;

  const WorkoutPage({
    super.key,
    required this.goToTemplateEditor,
  });

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with AfterLayoutMixin {
  final _workoutNameController = TextEditingController();
  final _workoutNameFocusNode = FocusNode();

  @override
  void dispose() {
    _workoutNameController.dispose();
    _workoutNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :textTheme, :colorScheme) = Theme.of(context);

    final L(:finish, :restTimer) = L.of(context);
    final workouts = Workouts.watch(context);

    if (workouts.activeWorkout?.name case String name when name.isNotEmpty) {
      _workoutNameController.text = name;
    }

    return SafeArea(
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (workouts.activeWorkout) {
            Workout active => WorkoutDetail(
                controller: Scrolls.of(context).workoutScrollController,
                exercises: active,
                allowsCompletingSet: true,
                onDragExercise: workouts.append,
                onAddSet: workouts.addSet,
                onRemoveSet: workouts.removeSet,
                onRemoveExercise: workouts.removeExercise,
                onSwapExercise: workouts.swap,
                onAddExercises: (exercises) async {
                  final workouts = Workouts.of(context);
                  // workouts.startExercise changes this iterable
                  // so we need a copy to avoid
                  // concurrent modification
                  for (var each in exercises.toList()) {
                    await Future.delayed(
                      // for different IDs
                      const Duration(milliseconds: 2),
                      () => workouts.startExercise(each),
                    );
                  }
                },
                appBar: SliverAppBar(
                  scrolledUnderElevation: 0,
                  backgroundColor: scaffoldBackgroundColor,
                  pinned: true,
                  expandedHeight: 80.0,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: TextField(
                      focusNode: _workoutNameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      textAlign: TextAlign.center,
                      controller: _workoutNameController,
                      style: textTheme.titleLarge,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      onEditingComplete: () {
                        final text = _workoutNameController.text.trim();
                        final name = switch (text.isEmpty) {
                          true => workouts.activeWorkout?.name?.trim() ?? L.of(context).defaultWorkoutName(),
                          false => text.trim(),
                        };
                        workouts.renameWorkout(name);
                        _workoutNameFocusNode.unfocus();
                      },
                      onTapOutside: (_) {
                        _workoutNameFocusNode.unfocus();
                      },
                    ),
                  ),
                ),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: FixedHeightHeaderDelegate(
                      backgroundColor: scaffoldBackgroundColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          WorkoutTimer(
                            start: active.start,
                            initValue: active.elapsed(),
                            style: textTheme.titleSmall,
                          ),
                          Selector<Alarms, (ValueNotifier<int>?, num?)>(
                            selector: (_, provider) => (provider.remainsInActiveExercise, provider.activeExerciseTotal),
                            builder: (_, seconds, __) {
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: switch (seconds) {
                                  (ValueNotifier<int> counter, num total) => ValueListenableBuilder<int>(
                                      valueListenable: counter,
                                      builder: (_, remains, __) {
                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox(
                                              height: 32,
                                              width: 32,
                                              child: CustomPaint(
                                                painter: CircularTimerPainter(
                                                  progress: remains / total,
                                                  strokeColor: colorScheme.primary,
                                                  backgroundColor: colorScheme.inversePrimary.withValues(alpha: .3),
                                                  strokeWidth: 3,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: restTimer,
                                              visualDensity: const VisualDensity(vertical: 0, horizontal: -2),
                                              icon: const Icon(Icons.timer_outlined),
                                              onPressed: () {
                                                showCountdownDialog(context, remains);
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  _ => const SizedBox.shrink(),
                                },
                              );
                            },
                          ),
                          PrimaryButton.shrunk(
                            onPressed: () {
                              showFinishWorkoutDialog(
                                context,
                                workouts,
                                onFinish: () {
                                  Scrolls.of(context)
                                    ..resetExerciseStack()
                                    ..resetHistoryStack();
                                },
                              );
                            },
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(finish),
                          )
                        ],
                      ),
                      height: 48,
                    ),
                  ),
                ],
              ),
            null => _NoActiveWorkoutLayout(goToTemplateEditor: widget.goToTemplateEditor),
          },
        ),
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    Workouts.of(context).notifyOfActiveWorkout();
  }
}
