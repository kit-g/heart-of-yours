import 'package:heart_models/heart_models.dart';

/// The muscle groups by family (#617): the coarser grouping History colours
/// by. Ten hues are too many to tell apart on a small dot, for every eye and
/// across every preset; six are not. A family always comes with its name —
/// colour is never the only carrier.
enum MuscleFamily {
  chest,
  back,
  shoulders,
  arms,
  core,
  lowerBody;

  /// The family [group] belongs to. Every group named, so one heart_models
  /// adds has to be placed here.
  static MuscleFamily of(MuscleGroupKey group) {
    return switch (group) {
      .chest => chest,
      .back => back,
      .shoulders || .neck => shoulders,
      .arms => arms,
      .core => core,
      .legs || .glutes || .hamstrings || .adductors => lowerBody,
    };
  }
}
