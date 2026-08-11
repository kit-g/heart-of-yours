part of 'goals.dart';

/// Composes one rung: a target, and a deadline if the user wants one.
///
/// Returns the edited [stage] with its id intact, so an achievement already
/// recorded against it survives the edit, or a new rung when [stage] is null.
Future<GoalStage?> showRungDialog(
  BuildContext context, {
  required Goal goal,
  required Exercise? exercise,
  GoalStage? stage,
}) {
  return showBrandedDialog<GoalStage?>(
    context,
    title: Text(L.of(context).goalTarget),
    content: _RungForm(goal: goal, stage: stage),
  );
}

class _RungForm extends StatefulWidget {
  final Goal goal;
  final GoalStage? stage;

  const _RungForm({required this.goal, this.stage});

  @override
  State<_RungForm> createState() => _RungFormState();
}

class _RungFormState extends State<_RungForm> {
  final _controller = TextEditingController();

  DateTime? _dueOn;

  @override
  void initState() {
    super.initState();

    _dueOn = widget.stage?.dueOn;

    if (widget.stage?.target case final num target) {
      final settings = Preferences.of(context);
      if (settings.isInitialized) {
        _controller.value = _formatters.fold(
          TextEditingValue(text: widget.goal.convert(settings, target).trimmed()),
          (value, formatter) => formatter.formatEditUpdate(TextEditingValue.empty, value),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<TextInputFormatter> get _formatters {
    return widget.goal.metric.chart?.formatters ??
        [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)];
  }

  double? get _typed {
    final text = _controller.text;
    final typed = widget.goal.metric.chart?.parseTyped(text) ?? double.tryParse(text.trim());
    return switch (typed) {
      final double value when value > 0 => value,
      _ => null,
    };
  }

  /// The target to save, or null while the field cannot yield a usable one.
  double? get _target => _typed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = Preferences.watch(context);
    final unit = widget.goal.metric.chart?.unitLabel(context, settings);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _formatters,
          decoration: InputDecoration(suffixText: unit),
        ),
        // A recurring goal has no deadline to set: its period *is* the
        // deadline, and it resets rather than falling due. Offering the control
        // would store a `dueOn` nothing ever reads.
        if (widget.goal.cadence == null)
          Align(
            alignment: .centerLeft,
            child: TextButton.icon(
              key: AppKeys.rungDueDate,
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event_rounded, size: 20),
              label: Text(
                switch (_dueOn) {
                  final DateTime due => DateFormat.yMMMd().format(due),
                  null => l.goalSetDeadline,
                },
              ),
            ),
          ),
        Row(
          mainAxisAlignment: .end,
          spacing: 8,
          children: [
            if (_dueOn != null && widget.goal.cadence == null)
              TextButton(
                onPressed: () => setState(() => _dueOn = null),
                child: Padding(
                  padding: const .symmetric(vertical: 1.0),
                  child: Text(l.goalClearDeadline),
                ),
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, _, _) {
                return PrimaryButton.shrunk(
                  onPressed: switch (_target) {
                    null => null,
                    _ => _submit,
                  },
                  // this dialog adds a *rung*, not a goal — the sheet that
                  // opened it says "Add milestone" and the button used to
                  // disagree with it at the moment of confirming
                  child: Text(widget.stage == null ? l.goalAddRung : l.save),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    // adaptive: a Material calendar grid is not what a date field looks like on
    // iOS, the same reason the rest timer forks
    final picked = await showAdaptiveDatePicker(
      context,
      initialDate: _dueOn,
      title: L.of(context).goalSetDeadline,
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  void _submit() {
    final typed = _target;
    if (typed == null) return;

    final settings = Preferences.of(context);
    final target = widget.goal.metric.chart?.storedValue(settings, typed) ?? typed;

    Navigator.of(context, rootNavigator: true).pop(
      GoalStage(
        // keeping the id is what lets an achievement survive an edit
        id: widget.stage?.id,
        target: target,
        dueOn: _dueOn,
        achievedAt: widget.stage?.achievedAt,
      ),
    );
  }
}
