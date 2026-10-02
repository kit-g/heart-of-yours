import 'package:material_ui/material_ui.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

/// What an opt-in [Feature] is called and how it is described — copy, so it
/// lives here rather than on the enum (see `docs/style.md`).
extension FeatureCopy on Feature {
  String title(L l) {
    return switch (this) {
      .muscleMap => l.muscleMap,
      .watchApp => l.watchApp,
    };
  }

  String subtitle(L l) {
    return switch (this) {
      .muscleMap => l.muscleMapSubtitle,
      .watchApp => l.watchAppSubtitle,
    };
  }

  IconData get icon {
    return switch (this) {
      .muscleMap => Icons.accessibility_new_rounded,
      .watchApp => Icons.watch_rounded,
    };
  }

  /// Lines of text under the feature's switch while it is on (#213): what is
  /// worth knowing about it, and that a control would not say.
  List<String> notes(L l) {
    return switch (this) {
      .muscleMap => const [],
      // where Apple keeps Always On: Heart has no switch of its own for it
      .watchApp => [l.watchAppAwayNote, l.watchAlwaysOnNote],
    };
  }
}

extension FeatureOptionCopy on FeatureOption {
  String title(L l) {
    return switch (this) {
      .muscleMapFigures => l.muscleMapOptionFigures,
      // the headings the widgets themselves carry
      .muscleMapBreakdown => l.muscleMapBreakdown,
      .muscleMapHeatmap => l.muscleMapWeekly,
    };
  }
}
