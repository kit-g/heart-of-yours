import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

// letters, digits and whitespace
final _formatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'));

Future<void> showNewExerciseDialog(BuildContext context) {
  final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
  final L(:createNewExercise, :save, :name, category: categoryCopy, target: targetCopy) = L.of(context);
  final category = ValueNotifier<Category?>(null);
  final target = ValueNotifier<Target?>(null);
  final loading = ValueNotifier(false);
  final nameController = TextEditingController();
  return showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Center(
        child: Wrap(
          children: [
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
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
                        child: ValueListenableBuilder<bool>(
                          valueListenable: loading,
                          builder: (_, l, _) {
                            return ValueListenableBuilder<Target?>(
                              valueListenable: target,
                              builder: (_, t, _) {
                                return ValueListenableBuilder<Category?>(
                                  valueListenable: category,
                                  builder: (_, c, _) {
                                    return ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: nameController,
                                      builder: (_, n, _) {
                                        final enough = t != null && c != null && n.text.isNotEmpty;
                                        return PrimaryButton.shrunk(
                                          onPressed: switch ((enough, l)) {
                                            (_, true) => null,
                                            (false, false) => null,
                                            (true, false) => () async {
                                              if (c != null && t != null) {
                                                final messenger = ScaffoldMessenger.of(context);
                                                final state = Navigator.of(context, rootNavigator: true);
                                                try {
                                                  loading.value = true;
                                                  final n = nameController.text.trim();
                                                  final exercise = Exercise(name: n, category: c, target: t);
                                                  await Exercises.of(context).makeExercise(exercise);
                                                  loading.value = false;
                                                  state.pop();
                                                } on ArgumentError catch (e) {
                                                  messenger.snack('${e.message}');
                                                } catch (e) {
                                                  messenger.snack('$e');
                                                } finally {
                                                  state.pop();
                                                  loading.value = false;
                                                }
                                              }
                                            },
                                          },
                                          child: Text(save),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      spacing: 12,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: textTheme.titleMedium,
                        ),
                        TextField(
                          controller: nameController,
                          inputFormatters: [_formatter],
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
                                        selected: each == selected,
                                        onSelected: (selected) {
                                          HapticFeedback.mediumImpact();
                                          target.value = selected ? each : null;
                                        },
                                        label: Text(each.value),
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
                                        selected: each == selected,
                                        onSelected: (selected) {
                                          HapticFeedback.mediumImpact();
                                          category.value = selected ? each : null;
                                        },
                                        label: Text(each.value),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
