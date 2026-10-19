part of 'settings.dart';

/// The warm-up ramp (#158), unfolded under its switch while warm-up sets are
/// on: a short list of percentage × reps rungs, lightest first. A rung opens
/// to change it; the last one cannot be removed, since a ramp of nothing is
/// the switch's job. Every change is live, and stored on this device.
class _WarmupScheme extends StatelessWidget with HasHaptic<_WarmupScheme> {
  const new();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final preferences = Preferences.watch(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:onSurfaceVariant)) = Theme.of(context);
    final scheme = preferences.warmupScheme;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(8, 8, 8, 4),
          child: Text(l.warmupSchemeHeading, style: textTheme.bodySmall?.copyWith(color: onSurfaceVariant)),
        ),
        for (final (index, step) in scheme.indexed)
          ListTile(
            key: ValueKey('warmup-step-$index'),
            dense: true,
            visualDensity: .compact,
            contentPadding: const .only(left: 8),
            shape: const RoundedRectangleBorder(borderRadius: .all(.circular(12))),
            title: Tooltip(
              message: l.warmupStepEdit(l.warmupStep(step.percent, step.reps)),
              child: Text(
                l.warmupStep(step.percent, step.reps),
                style: textTheme.bodyLarge?.copyWith(fontFeatures: const [.tabularFigures()]),
              ),
            ),
            onTap: () => _edit(context, scheme, index),
            trailing: switch (scheme.length) {
              1 => null,
              _ => IconButton(
                tooltip: l.warmupStepRemove(l.warmupStep(step.percent, step.reps)),
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  buzz();
                  preferences.setWarmupScheme([...scheme]..removeAt(index));
                },
              ),
            },
          ),
        Wrap(
          spacing: 8,
          children: [
            if (scheme.length < maxWarmupSteps)
              TextButton.icon(
                key: const ValueKey('warmup-step-add'),
                icon: const Icon(Icons.add_rounded),
                label: Text(l.warmupStepAdd),
                onPressed: () => _edit(context, scheme, null),
              ),
            if (!listEquals(scheme, defaultWarmupScheme))
              TextButton(
                key: const ValueKey('warmup-scheme-reset'),
                onPressed: () {
                  buzz();
                  preferences.setWarmupScheme(defaultWarmupScheme);
                },
                child: Text(l.warmupSchemeReset),
              ),
          ],
        ),
      ],
    );
  }

  /// Changes rung [index] of [scheme], or adds one when it is null — halfway
  /// from the heaviest to the working weight, once.
  Future<void> _edit(BuildContext context, List<WarmupStep> scheme, int? index) async {
    buzz();
    final preferences = Preferences.of(context);
    final initial = switch (index) {
      final int index => scheme[index],
      null => (percent: ((scheme.last.percent + 100) / 2).round().clamp(1, 99), reps: 1),
    };
    final step = await showBrandedDialog<WarmupStep>(
      context,
      title: Text(L.of(context).warmupStepTitle, textAlign: .center),
      content: _WarmupStepForm(initial: initial),
    );
    if (step == null) return;
    preferences.setWarmupScheme(switch (index) {
      final int index => [...scheme]..[index] = step,
      null => [...scheme, step],
    });
  }
}

/// A rung's two numbers. Returns the rung on Save; a pair the ramp cannot hold
/// marks both fields rather than closing.
class _WarmupStepForm extends StatefulWidget {
  final WarmupStep initial;

  const new({required this.initial});

  @override
  State<_WarmupStepForm> createState() => _WarmupStepFormState();
}

class _WarmupStepFormState extends State<_WarmupStepForm> {
  late final _percent = TextEditingController(text: '${widget.initial.percent}');
  late final _reps = TextEditingController(text: '${widget.initial.reps}');
  final _error = ValueNotifier(false);

  @override
  void dispose() {
    _percent.dispose();
    _reps.dispose();
    _error.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:onSurfaceVariant)) = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _error,
      builder: (context, error, _) {
        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            _field(const ValueKey('warmup-step-percent'), l.warmupStepPercent, _percent, error: error),
            _field(const ValueKey('warmup-step-reps'), l.reps, _reps, error: error),
            Text(l.warmupStepLimits, style: textTheme.bodySmall?.copyWith(color: onSurfaceVariant)),
            Align(
              alignment: .centerRight,
              child: PrimaryButton.shrunk(
                key: const ValueKey('warmup-step-save'),
                onPressed: _submit,
                child: Padding(
                  padding: const .symmetric(horizontal: 12, vertical: 6),
                  child: Text(l.save),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _field(Key key, String label, TextEditingController controller, {required bool error}) {
    return Row(
      spacing: 8,
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 72,
          child: Semantics(
            label: label,
            child: TextField(
              key: key,
              controller: controller,
              keyboardType: .number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              textAlign: .center,
              decoration: InputDecoration(
                isDense: true,
                // the pair is what the ramp refuses, so neither field gets a
                // line of its own
                error: error ? const SizedBox.shrink() : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final step = switch ((int.tryParse(_percent.text), int.tryParse(_reps.text))) {
      (final int percent, final int reps) when isWarmupStep((percent: percent, reps: reps)) => (
        percent: percent,
        reps: reps,
      ),
      _ => null,
    };
    _error.value = step == null;
    if (step != null) Navigator.of(context).pop(step);
  }
}
