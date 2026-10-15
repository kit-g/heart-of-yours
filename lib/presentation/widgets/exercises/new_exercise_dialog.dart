import 'package:flutter/services.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/exercises/movement_copy.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/selection_controls.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

// letters, digits and whitespace
final _formatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'));

// a pattern's label runs to "Trunk Lateral Rotation"; 56pt steps (the popup's)
const _patternMenuWidth = 280.0;

Future<void> showNewExerciseDialog(BuildContext context, {Exercise? editable}) {
  final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
  final L(:createNewExercise, :save, :name, category: categoryCopy, target: targetCopy) = L.of(context);
  final category = ValueNotifier<Category?>(editable?.category);
  final target = ValueNotifier<Target?>(editable?.target);
  // one of the library's patterns, or none: optional, and never asked twice
  // (#343)
  final pattern = ValueNotifier<String?>(editable?.movement.groups.firstOrNull);
  final patternKey = GlobalKey();
  final loading = ValueNotifier(false);
  final nameController = TextEditingController();
  return showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Center(
        // clear of the keyboard, so the body below scrolls rather than hides
        child: Padding(
          padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.symmetric(vertical: 24),
          child: ConstrainedBox(
            // the width needs bounding or the card takes the whole screen
            constraints: const BoxConstraints(maxWidth: dialogWidth),
            child: Card(
              // shrink-wraps while it fits; past that the header with Save
              // stays put and the ten targets and ten categories scroll
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      IconButton(
                        tooltip: L.of(context).close,
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Text(
                        createNewExercise,
                        style: textTheme.titleMedium,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ListenableBuilder(
                          listenable: Listenable.merge([loading, target, category, pattern, nameController]),
                          builder: (_, _) {
                            final (l, t, c, p, n) = (
                              loading.value,
                              target.value,
                              category.value,
                              pattern.value,
                              nameController.value,
                            );
                            final enough = switch (editable) {
                              Exercise e =>
                                t != null && c != null && (e.category != c || e.movement.groups.firstOrNull != p),
                              null => t != null && c != null && n.text.isNotEmpty,
                            };
                            final movement = _withPattern(editable?.movement ?? Movement.empty(), p);
                            return PrimaryButton.shrunk(
                              onPressed: switch ((enough, l)) {
                                (_, true) => null,
                                (false, false) => null,
                                (true, false) => () async {
                                  if (c != null && t != null) {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final root = Navigator.of(context, rootNavigator: true);
                                    try {
                                      loading.value = true;
                                      if (editable == null) {
                                        final n = nameController.text.trim();
                                        final exercise = Exercise(
                                          name: n,
                                          category: c,
                                          target: t,
                                          isMine: true,
                                          movement: movement,
                                        );
                                        await Exercises.of(context).makeExercise(exercise);
                                      } else {
                                        final edited = editable.copyWith(category: c, movement: movement);
                                        await Exercises.of(context).editExercise(edited);
                                      }
                                      loading.value = false;
                                    } on ArgumentError catch (e) {
                                      messenger.snack('${e.message}');
                                    } catch (e) {
                                      messenger.snack('$e');
                                    } finally {
                                      root.pop();
                                      loading.value = false;
                                    }
                                  }
                                },
                              },
                              child: Text(save),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        spacing: 12,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: textTheme.titleMedium,
                          ),
                          if (editable == null)
                            TextField(
                              controller: nameController,
                              inputFormatters: [_formatter],
                              selectionControls: context.platformSpecificSelectionControls(),
                            )
                          else
                            Center(
                              child: Text(
                                editable.name,
                                style: textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Text(
                            targetCopy,
                            style: textTheme.titleMedium,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ValueListenableBuilder<Target?>(
                              valueListenable: target,
                              builder: (context, selected, child) {
                                return Wrap(
                                  spacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ...Target.values.map(
                                      (each) {
                                        return InputChip(
                                          isEnabled: editable == null, // new exercise
                                          selected: each == selected,
                                          onSelected: (selected) {
                                            HapticFeedback.mediumImpact();
                                            target.value = selected ? each : null;
                                          },
                                          label: Text(each.label(L.of(context))),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Text(
                            categoryCopy,
                            style: textTheme.titleMedium,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ValueListenableBuilder<Category?>(
                              valueListenable: category,
                              builder: (context, selected, child) {
                                return Wrap(
                                  spacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ...Category.values.map(
                                      (each) {
                                        return InputChip(
                                          isEnabled: switch (editable) {
                                            null => true,
                                            Exercise() => selected?.canSwitchTo(each) ?? true,
                                          },
                                          selected: each == selected,
                                          onSelected: (selected) {
                                            HapticFeedback.mediumImpact();
                                            category.value = selected ? each : null;
                                          },
                                          label: Text(each.label(L.of(context))),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          ValueListenableBuilder<String?>(
                            valueListenable: pattern,
                            builder: (context, selected, _) {
                              final l = L.of(context);
                              return ListTile(
                                key: AppKeys.newExercisePattern,
                                contentPadding: .zero,
                                title: Text(l.exercisePattern, style: textTheme.titleMedium),
                                // the menu hangs off the value, not the row's far-left edge
                                trailing: Row(
                                  key: patternKey,
                                  mainAxisSize: .min,
                                  spacing: 4,
                                  children: [
                                    Text(_patternLabel(selected, l), style: textTheme.bodyMedium),
                                    const Icon(Icons.unfold_more_rounded, size: 20),
                                  ],
                                ),
                                onTap: () => _pickPattern(context, patternKey, pattern),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _patternLabel(String? pattern, L l) {
  return switch (pattern) {
    String key => PatternFilter(key).label(l),
    null => l.exercisePatternNone,
  };
}

/// The library's patterns, most used first as in the filter sheet, under
/// "None": the same keys and the same labels the filters show (#343).
Future<void> _pickPattern(BuildContext context, GlobalKey key, ValueNotifier<String?> pattern) {
  final l = L.of(context);
  HapticFeedback.selectionClick();
  return showMenu<void>(
    context: context,
    position: menuUnderValue(context, key, width: _patternMenuWidth),
    constraints: const BoxConstraints(minWidth: _patternMenuWidth, maxWidth: _patternMenuWidth),
    items: [
      for (final each in <String?>[null, ...Exercises.of(context).patterns])
        PopupMenuItem<void>(
          key: AppKeys.newExercisePatternOption(each),
          // on the item, not the menu's result: a dismissed menu and "None"
          // would both come back as null
          onTap: () => pattern.value = each,
          child: Text(_patternLabel(each, l)),
        ),
    ],
  );
}

/// [movement] with [pattern] as its first group, the one this dialog asks
/// about: the same movement when the answer didn't change, and otherwise
/// only that group swapped — the other groups and the load attributes are
/// facts the dialog never showed, so it keeps them.
Movement _withPattern(Movement movement, String? pattern) {
  if (movement.groups.firstOrNull == pattern) return movement;
  final rest = movement.groups.skip(1).where((group) => group != pattern);
  return Movement.fromJson({
    ...movement.toMap(),
    'groups': [?pattern, ...rest],
  });
}
