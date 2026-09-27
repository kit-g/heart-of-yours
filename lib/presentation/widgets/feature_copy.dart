import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

/// What an opt-in [Feature] is called and how it is described — copy, so it
/// lives here rather than on the enum (see `docs/style.md`).
extension FeatureCopy on Feature {
  String title(L l) {
    return switch (this) {
      .muscleMap => l.muscleMap,
    };
  }

  String subtitle(L l) {
    return switch (this) {
      .muscleMap => l.muscleMapSubtitle,
    };
  }

  IconData get icon {
    return switch (this) {
      .muscleMap => Icons.accessibility_new_rounded,
    };
  }
}
