import 'package:flutter/services.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/exercises/movement_copy.dart';
import 'package:heart/presentation/widgets/exercises/muscle_picker.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/selection_controls.dart';
import 'package:heart_api/heart_api.dart' show ExerciseNameTaken;
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

// A name is display copy in any script, with the punctuation real names carry
// ("T-bar row", "Farmer's walk", "Жим лёжа"): only control characters, such
// as a pasted tab or line break, stay out (#527).
final _formatter = FilteringTextInputFormatter.deny(RegExp(r'\p{Cc}', unicode: true));

// the server's limit on a name, created or renamed (heart-api#429)
final _length = LengthLimitingTextInputFormatter(200);

/// A name as a library search would hear it: letters and digits only, any
/// case — "Farmer's walk" and "Farmer's Walk" are one name.
String _nameKey(String name) => name.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

// a pattern's label runs to "Trunk Lateral Rotation"; 56pt steps (the popup's)
const _patternMenuWidth = 280.0;

/// Creates an exercise, or edits [editable], and answers with the one saved:
/// null when the dialog was closed or the save failed. [name] fills in a new
/// exercise's name, such as a search that found nothing (#529).
Future<Exercise?> showNewExerciseDialog(BuildContext context, {Exercise? editable, String? name}) {
  // the current copy, not the one the caller holds: a page opened before an
  // edit still has the old name, and saving from it would put that back
  final current = switch (editable) {
    Exercise given => Exercises.of(context).lookup(given.id) ?? given,
    null => null,
  };
  return _showDialog(context, editable: current, name: name);
}

/// Whether another of the account's own exercises, archived ones included,
/// already goes by [typed], as the server matches names: case aside. It
/// refuses such a rename, so the dialog says so before Save does (#616).
bool _ownNameTaken(Exercises exercises, Exercise editable, String typed) {
  final wanted = typed.toLowerCase();
  return [...exercises, ...exercises.archived].any(
    (each) => each.isMine && each.id != editable.id && each.name.trim().toLowerCase() == wanted,
  );
}

Future<Exercise?> _showDialog(BuildContext context, {Exercise? editable, String? name}) {
  final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
  final L(:createNewExercise, :save, name: nameCopy, category: categoryCopy, target: targetCopy) = L.of(context);
  final category = ValueNotifier<Category?>(editable?.category);
  final target = ValueNotifier<Target?>(editable?.target);
  // one of the library's patterns, or none: optional, and never asked twice
  // (#343)
  final pattern = ValueNotifier<String?>(editable?.movement.groups.firstOrNull);
  final patternKey = GlobalKey();
  // tagged on the body atlas, so the muscle map counts its sets (#176)
  final initialRoles = rolesOf(editable?.muscles ?? MuscleTagging.empty());
  final roles = ValueNotifier(initialRoles);
  final loading = ValueNotifier(false);
  // an own exercise is renamable: its id is the identity, the name only copy
  // (#616); the library's names are the library's
  final renamable = editable?.isMine ?? true;
  final nameController = TextEditingController(text: editable?.name ?? name);
  // the server's 409, for a name taken since the dialog checked; cleared by
  // the next keystroke
  final refused = ValueNotifier(false);
  nameController.addListener(() => refused.value = false);
  return showDialog<Exercise>(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      // A save in flight holds the dialog open: closing it under the save left
      // the save's own pop to take whatever sat beneath — on Android, the
      // shell's page — and the next Back crashed the router (#607).
      return ValueListenableBuilder<bool>(
        valueListenable: loading,
        builder: (context, saving, child) => PopScope(canPop: !saving, child: child!),
        child: Center(
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
                          // maybe: it asks the dialog's PopScope, which says no mid-save
                          onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        Text(
                          createNewExercise,
                          style: textTheme.titleMedium,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ListenableBuilder(
                            listenable: Listenable.merge([loading, target, category, pattern, roles, nameController]),
                            builder: (_, _) {
                              final (l, t, c, p, r, n) = (
                                loading.value,
                                target.value,
                                category.value,
                                pattern.value,
                                roles.value,
                                nameController.value,
                              );
                              final retagged = !sameRoles(r, initialRoles);
                              final typed = n.text.trim();
                              final enough = switch (editable) {
                                Exercise e =>
                                  t != null &&
                                      c != null &&
                                      typed.isNotEmpty &&
                                      !_ownNameTaken(Exercises.of(context), e, typed) &&
                                      (typed != e.name.trim() ||
                                          e.target != t ||
                                          e.category != c ||
                                          e.movement.groups.firstOrNull != p ||
                                          retagged),
                                null => t != null && c != null && typed.isNotEmpty,
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
                                      final route = ModalRoute.of<Exercise>(context);
                                      Exercise? saved;
                                      // a name already taken is the one refusal worth staying
                                      // open for: the fix is a keystroke away, and the field
                                      // says why, where a snack would sit under the barrier
                                      var close = true;
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
                                            tags: taggingOf(r),
                                          );
                                          await Exercises.of(context).makeExercise(exercise);
                                          saved = exercise;
                                        } else {
                                          // a stored name padded with whitespace is not a rename
                                          final named = typed == editable.name.trim()
                                              ? editable
                                              : editable.renamed(typed);
                                          final edited = named.copyWith(
                                            category: c,
                                            target: t,
                                            movement: movement,
                                            // untouched, the tagging stays exactly as it was
                                            tags: retagged ? taggingOf(r) : null,
                                          );
                                          await Exercises.of(context).editExercise(edited);
                                          saved = edited;
                                        }
                                        loading.value = false;
                                      } on ExerciseNameTaken {
                                        close = false;
                                        refused.value = true;
                                      } on ArgumentError catch (e) {
                                        messenger.snack('${e.message}');
                                      } catch (e) {
                                        messenger.snack('$e');
                                      } finally {
                                        loading.value = false;
                                        // this dialog's route and nothing else: a bare pop
                                        // takes whatever is on top by then
                                        switch (route) {
                                          case _ when !close:
                                            break;
                                          case ModalRoute<Exercise>(isCurrent: true):
                                            root.pop(saved);
                                          case final ModalRoute<Exercise> route when route.isActive:
                                            root.removeRoute(route, saved);
                                          default:
                                            break;
                                        }
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
                              nameCopy,
                              style: textTheme.titleMedium,
                            ),
                            if (renamable)
                              ListenableBuilder(
                                listenable: Listenable.merge([nameController, refused]),
                                builder: (context, _) {
                                  final taken = switch (editable) {
                                    Exercise e => _ownNameTaken(Exercises.of(context), e, nameController.text.trim()),
                                    null => false,
                                  };
                                  return TextField(
                                    controller: nameController,
                                    inputFormatters: [_formatter, _length],
                                    selectionControls: context.platformSpecificSelectionControls(),
                                    decoration: InputDecoration(
                                      errorText: taken || refused.value ? L.of(context).exerciseNameTaken : null,
                                    ),
                                  );
                                },
                              ),
                            // the same name in the library, told apart only by case
                            // or punctuation: said, not refused, since a machine at
                            // one gym can share a name with the library's (#529)
                            if (renamable)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: nameController,
                                builder: (context, value, _) {
                                  final key = _nameKey(value.text);
                                  final twin = switch (key.isEmpty) {
                                    true => null,
                                    false =>
                                      Exercises.of(
                                            context,
                                          )
                                          .where((each) => each.id != editable?.id && _nameKey(each.name) == key)
                                          .firstOrNull,
                                  };
                                  return switch (twin) {
                                    Exercise twin => Text(
                                      L.of(context).exerciseAlreadyInLibrary(twin.name),
                                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                    null => const SizedBox.shrink(),
                                  };
                                },
                              )
                            else
                              Center(
                                child: Text(
                                  nameController.text,
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
                                            // a label, not a shape: unlike category, it decides
                                            // no column a set is logged in, so an own exercise
                                            // can change it as freely as its name (#616)
                                            isEnabled: renamable,
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
                            MusclePicker(roles: roles),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
