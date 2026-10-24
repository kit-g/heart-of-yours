part of 'workout_detail.dart';

const _barMenuWidth = 280.0;

/// The weight being typed on a set the plate calculator can load (#132): a
/// barbell or machine exercise, in the active workout.
final class _PlateTarget {
  final Exercise exercise;

  /// The set's weight field, in the exercise's unit ([unit]).
  final TextEditingController field;
  final MeasurementUnit unit;

  /// The set's row, kept in view above the bar.
  final BuildContext row;

  const new({required this.exercise, required this.field, required this.unit, required this.row});

  /// The weight in the field; null while it holds none.
  double? get weight {
    return switch (double.tryParse(field.text)) {
      double weight when weight > 0 => weight,
      _ => null,
    };
  }
}

/// Where a set's weight field says it is being typed into, for [_PlatesBar].
/// Only the active workout has one: a template or a past workout is not where
/// anyone loads a bar.
class _PlatesScope extends InheritedWidget {
  final ValueNotifier<_PlateTarget?> target;

  const new({required this.target, required super.child});

  static ValueNotifier<_PlateTarget?>? of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_PlatesScope>()?.target;
  }

  @override
  bool updateShouldNotify(_PlatesScope oldWidget) => target != oldWidget.target;
}

/// Whether [category] is loaded with plates: a barbell, or a plate-loaded
/// machine. Dumbbells are not (#132).
bool _takesPlates(Category category) {
  return switch (category) {
    .barbell || .machine => true,
    .dumbbell ||
    .weightedBodyWeight ||
    .assistedBodyWeight ||
    .repsOnly ||
    .cardio ||
    .duration ||
    .weightedDistance ||
    .weightedDuration => false,
  };
}

/// [value] as the calculator writes it: up to two decimals, so a 1.25 plate
/// is not rounded to 1.3 the way set weights are.
String _plateNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
}

/// [value] with its unit: "102.5 kg".
String _plateWeight(L l, double value, MeasurementUnit unit) => '${_plateNumber(value)} ${_unitLabel(l, unit)}';

String _unitLabel(L l, MeasurementUnit unit) {
  return switch (unit) {
    .metric => l.kg,
    .imperial => l.lbs,
  };
}

/// One side's plates in words, heaviest first: "2 × 20 + 5 kg".
String _perSideText(L l, List<double> plates, MeasurementUnit unit) {
  final counts = plates.fold(<double, int>{}, (counts, plate) {
    return counts..update(plate, (count) => count + 1, ifAbsent: () => 1);
  });
  final groups = counts.entries.map((each) {
    final number = _plateNumber(each.key);
    return each.value > 1 ? '${each.value} × $number' : number;
  });
  return '${groups.join(' + ')} ${_unitLabel(l, unit)}';
}

/// The strip over the keyboard while a barbell or machine weight is typed in
/// the active workout (#132): the way into the plate calculator, and where it
/// is offered, once.
///
/// Off, unoffered and without its notice, it is nothing at all, and the sheet
/// is what it was before the calculator existed.
class _PlatesBar extends StatefulWidget {
  final ValueNotifier<_PlateTarget?> target;

  const new({required this.target});

  @override
  State<_PlatesBar> createState() => _PlatesBarState();
}

class _PlatesBarState extends State<_PlatesBar> {
  static const _feature = Feature.plateCalculator;

  @override
  void initState() {
    super.initState();
    widget.target.addListener(_keepRowInView);
  }

  @override
  void dispose() {
    widget.target.removeListener(_keepRowInView);
    super.dispose();
  }

  /// The strip takes height from the list: the row being typed into must not
  /// end up under it.
  void _keepRowInView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.target.value?.row case final BuildContext row when row.mounted) {
        Scrollable.ensureVisible(
          row,
          alignmentPolicy: .keepVisibleAtEnd,
          duration: const Duration(milliseconds: 150),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_PlateTarget?>(
      valueListenable: widget.target,
      builder: (context, target, _) {
        // the way in follows the field: nothing to load while it holds nothing
        return ListenableBuilder(
          listenable: Listenable.merge([?target?.field]),
          builder: (context, _) => _strip(context, target),
        );
      },
    );
  }

  Widget _strip(BuildContext context, _PlateTarget? target) {
    final preferences = Preferences.watch(context);
    final Widget? child = switch (target) {
      null => null,
      // the row went while its field had the keyboard
      _PlateTarget(:final row) when !row.mounted => null,
      _PlateTarget(:final weight?) when preferences.isOn(_feature) => _PlatesButton(target: target, weight: weight),
      _ when preferences.isOn(_feature) => null,
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      _ when preferences.shouldOffer(_feature) => FeatureOffer(
        key: WorkoutDetailKeys.platesOffer,
        acceptKey: WorkoutDetailKeys.platesAccept,
        declineKey: WorkoutDetailKeys.platesDecline,
        icon: _feature.icon,
        title: L.of(context).plateCalculatorOfferTitle,
        body: L.of(context).plateCalculatorOfferBody,
        onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
        onShown: () => preferences.markOffered(_feature),
      ),
      _ => null,
    };
    return switch (child) {
      // a tap here is not a tap away from the field: it keeps the keyboard
      Widget child => TextFieldTapRegion(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: .5)),
          ),
          // over the home indicator when there is no keyboard to sit on
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const .symmetric(horizontal: 16, vertical: 8),
              child: child,
            ),
          ),
        ),
      ),
      null => const SizedBox.shrink(),
    };
  }
}

/// "Plates for 100 kg": the way into the calculator.
class _PlatesButton extends StatelessWidget {
  final _PlateTarget target;
  final double weight;

  const new({required this.target, required this.weight});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Align(
      alignment: .centerLeft,
      child: PrimaryButton.shrunk(
        key: WorkoutDetailKeys.platesButton,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        onPressed: () {
          FocusScope.of(context).unfocus();
          _showPlateCalculator(context, target);
        },
        child: Row(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            const Icon(Icons.fitness_center_rounded, size: 18),
            Text(l.platesFor(_plateWeight(l, weight, target.unit))),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPlateCalculator(BuildContext context, _PlateTarget target) {
  final preferences = Preferences.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (_) => _PlateCalculator(target: target, preferences: preferences),
  );
}

/// The plate calculator (#132): the plates on each side for the set's weight,
/// drawn and in words; the nearest weights either side when the plates cannot
/// make it; and, under that, the exercise's bar and the plates the gym has —
/// both live, so a change shows in the plates at once.
class _PlateCalculator extends StatelessWidget {
  final _PlateTarget target;

  /// Passed in: the sheet is a route of its own.
  final Preferences preferences;

  const new({required this.target, required this.preferences});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final _PlateTarget(:exercise, :unit, :field) = target;

    return ListenableBuilder(
      listenable: Listenable.merge([preferences, field]),
      builder: (context, _) {
        final weight = target.weight ?? 0;
        final bar = preferences.barWeightFor(exercise);
        final barWeight = bar.weightIn(unit);
        final plates = preferences.platesIn(unit);
        final result = loadPlates(target: weight, bar: barWeight, plates: plates);
        final machine = exercise.category == .machine;

        return SafeArea(
          child: SingleChildScrollView(
            key: WorkoutDetailKeys.plateCalculator,
            padding: const .fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: .stretch,
              mainAxisSize: .min,
              spacing: 12,
              children: [
                Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    Text(l.platesFor(_plateWeight(l, weight, unit)), style: textTheme.titleMedium),
                    Text(
                      exercise.name,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                ...switch (result) {
                  ExactLoad(:final load) => [
                    _PlatePicture(load: load, unit: unit),
                    Text(_loadText(l, load, unit), style: textTheme.bodyLarge),
                  ],
                  NearestLoads(:final below, :final above) => [
                    Text(l.platesCannotMake(_plateWeight(l, weight, unit)), style: textTheme.bodyMedium),
                    for (final load in [below, ?above]) _NearestLoad(load: load, unit: unit, field: field),
                  ],
                  UnderBar() => [
                    Text(
                      switch (machine) {
                        true => l.platesUnderStart(_plateWeight(l, barWeight, unit)),
                        false => l.platesUnderBar(_plateWeight(l, barWeight, unit)),
                      },
                      style: textTheme.bodyLarge,
                    ),
                  ],
                },
                const Divider(height: 8),
                _BarRow(exercise: exercise, unit: unit, bar: bar, preferences: preferences),
                Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    Text(l.platesYouHave, style: textTheme.titleSmall),
                    Text(
                      l.platesYouHaveHint,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final plate in standardPlates(unit))
                      FilterChip(
                        key: WorkoutDetailKeys.plateChip('$plate'),
                        label: Text(_plateWeight(l, plate, unit), style: textTheme.bodyMedium),
                        visualDensity: const VisualDensity(vertical: -2, horizontal: -2),
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        selected: plates.contains(plate),
                        onSelected: (on) => preferences.setPlate(unit, plate, on: on),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _loadText(L l, PlateLoad load, MeasurementUnit unit) {
    return switch (load.perSide) {
      [] => l.platesNone,
      final plates => l.platesEachSide(_perSideText(l, plates, unit)),
    };
  }
}

/// A weight the plates can make, near the one asked for: its plates, and a
/// button putting it in the set.
class _NearestLoad extends StatelessWidget {
  final PlateLoad load;
  final MeasurementUnit unit;
  final TextEditingController field;

  const new({required this.load, required this.unit, required this.field});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final shown = _plateWeight(l, load.total, unit);
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            _PlateCalculator._loadText(l, load, unit),
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        PrimaryButton.shrunk(
          key: WorkoutDetailKeys.plateNearest('${load.total}'),
          onPressed: () => field.text = _plateNumber(load.total),
          child: Text(l.platesUse(shown)),
        ),
      ],
    );
  }
}

/// What the exercise's bar weighs, and the popup that changes it: the named
/// bars, and a weight of the user's own.
class _BarRow extends StatefulWidget {
  final Exercise exercise;
  final MeasurementUnit unit;
  final BarWeight bar;
  final Preferences preferences;

  const new({required this.exercise, required this.unit, required this.bar, required this.preferences});

  @override
  State<_BarRow> createState() => _BarRowState();
}

/// Stateful only to own the key the popup hangs off: a static one would be
/// claimed twice while a closing sheet and a reopened one overlap.
class _BarRowState extends State<_BarRow> {
  final _valueKey = GlobalKey();

  Exercise get exercise => widget.exercise;

  MeasurementUnit get unit => widget.unit;

  BarWeight get bar => widget.bar;

  Preferences get preferences => widget.preferences;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final label = switch (exercise.category == .machine) {
      true => l.platesStartingWeight,
      false => l.platesBar,
    };
    final shown = _plateWeight(l, bar.weightIn(unit), unit);

    return Semantics(
      button: true,
      label: '$label, $shown',
      excludeSemantics: true,
      child: InkWell(
        key: WorkoutDetailKeys.plateBar,
        borderRadius: const .all(.circular(8)),
        onTap: () => _pick(context, label),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: Text(label, style: textTheme.titleSmall)),
              Row(
                key: _valueKey,
                mainAxisSize: .min,
                spacing: 4,
                children: [
                  Text(shown, style: textTheme.bodyLarge),
                  Icon(Icons.unfold_more_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, String label) async {
    final l = L.of(context);
    final picked = await showMenu<_BarChoice>(
      context: context,
      position: menuUnderValue(context, _valueKey, width: _barMenuWidth),
      constraints: const BoxConstraints(minWidth: _barMenuWidth, maxWidth: _barMenuWidth),
      items: [
        for (final each in Bar.values)
          PopupMenuItem<_BarChoice>(
            value: _NamedChoice(each),
            key: WorkoutDetailKeys.barOption(each.value),
            child: Row(
              children: [
                Expanded(child: Text(each.label(l))),
                Text(_plateWeight(l, each.weightIn(unit), unit)),
              ],
            ),
          ),
        PopupMenuItem<_BarChoice>(
          value: const _OtherChoice(),
          key: WorkoutDetailKeys.barOption('custom'),
          child: Text(l.barOther),
        ),
      ],
    );
    if (!context.mounted) return;
    switch (picked) {
      case _NamedChoice(:final bar):
        preferences.setBarWeight(exercise, NamedBar(bar));
      case _OtherChoice():
        final typed = await showDialog<double>(
          context: context,
          builder: (_) => _CustomBarDialog(title: label, unit: unit, initial: bar.weightIn(unit)),
        );
        if (typed case double value) preferences.setBarWeight(exercise, CustomBar(value, unit));
      case null:
    }
  }
}

/// What the bar popup returns: a named bar, or the way to type one.
sealed class _BarChoice {
  const new();
}

final class _NamedChoice extends _BarChoice {
  final Bar bar;

  const new(this.bar);
}

final class _OtherChoice extends _BarChoice {
  const new();
}

extension on Bar {
  String label(L l) {
    return switch (this) {
      .olympic => l.barOlympic,
      .womens => l.barWomens,
      .ez => l.barEz,
      .trap => l.barTrap,
      .smith => l.barSmith,
      .none => l.barNone,
    };
  }
}

/// A bar weight of the user's own, in the unit the set is in.
class _CustomBarDialog extends StatefulWidget {
  final String title;
  final MeasurementUnit unit;
  final double initial;

  const new({required this.title, required this.unit, required this.initial});

  @override
  State<_CustomBarDialog> createState() => _CustomBarDialogState();
}

class _CustomBarDialogState extends State<_CustomBarDialog> {
  late final _field = TextEditingController(text: _plateNumber(widget.initial));

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    if (double.tryParse(_field.text) case double value when value >= 0) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: dialogWidth),
        child: TextField(
          key: WorkoutDetailKeys.customBarField,
          controller: _field,
          autofocus: true,
          keyboardType: const .numberWithOptions(decimal: true),
          inputFormatters: _floatingPointFormatters,
          decoration: InputDecoration(suffixText: _unitLabel(l, widget.unit)),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        TextButton(key: WorkoutDetailKeys.customBarSave, onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

/// One sleeve of the bar, loaded: the collar, then the plates outward,
/// heaviest first, each sized and coloured by its weight the way gym plates
/// are, and each with its weight printed on it. Silent to a screen reader: the
/// line under it says the same in words.
class _PlatePicture extends StatelessWidget {
  final PlateLoad load;
  final MeasurementUnit unit;

  const new({required this.load, required this.unit});

  /// Competition colours by size, heaviest first: the kilogram set's own, and
  /// the pound set's nearest equivalents.
  static const _kgColors = [
    Color(0xFFD32F2F), // 25
    Color(0xFF1E5AA8), // 20
    Color(0xFFF2C230), // 15
    Color(0xFF2E8B57), // 10
    Color(0xFFF5F5F5), // 5
    Color(0xFFB71C1C), // 2.5
    Color(0xFFB0B0B0), // 1.25
  ];
  static const _lbColors = [
    Color(0xFF1E5AA8), // 45
    Color(0xFFF2C230), // 35
    Color(0xFF2E8B57), // 25
    Color(0xFFF5F5F5), // 10
    Color(0xFFB71C1C), // 5
    Color(0xFFB0B0B0), // 2.5
  ];

  static const _height = 120.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, colorScheme: ColorScheme(:outline, :outlineVariant, :onSurfaceVariant)) = Theme.of(
      context,
    );
    final standard = standardPlates(unit);
    final colors = switch (unit) {
      .metric => _kgColors,
      .imperial => _lbColors,
    };
    final heaviest = standard.first;

    Widget plate(double weight) {
      final rank = standard.indexOf(weight);
      // the big plates share one diameter, as they do in a gym; the change
      // plates step down from there
      final height =
          _height *
          switch (weight / heaviest) {
            >= .4 => 1.0,
            final ratio => .35 + ratio * 1.2,
          };
      final color = switch (rank) {
        -1 => outline,
        _ => colors[rank],
      };
      // the number, as a real plate carries it: colours vary from gym to gym,
      // and mean nothing to someone new to them
      return Container(
        width: weight / heaviest >= .4 ? 22 : 16,
        height: height,
        margin: const .symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          border: .all(color: outline, width: .5),
          borderRadius: const .all(.circular(3)),
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Center(
            child: Text(
              _plateNumber(weight),
              maxLines: 1,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: .w700,
                height: 1,
                color: switch (ThemeData.estimateBrightnessForColor(color)) {
                  .dark => Colors.white,
                  .light => Colors.black87,
                },
              ),
            ),
          ),
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox(
        height: _height,
        child: FittedBox(
          fit: .scaleDown,
          alignment: .centerLeft,
          child: Row(
            mainAxisSize: .min,
            children: [
              // the shaft, where the hands go
              Container(width: 40, height: 10, color: outlineVariant),
              // the collar
              Container(
                width: 8,
                height: 28,
                decoration: BoxDecoration(color: onSurfaceVariant, borderRadius: const .all(.circular(2))),
              ),
              ...load.perSide.map(plate),
              // the rest of the sleeve, past the last plate
              Container(width: 36, height: 14, color: outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
