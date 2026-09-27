/// A feature the user opts into (#138, `docs/opt-in.md`).
///
/// Everything the app shipped as of 1.9.0 is core and is not listed here.
/// Anything after it is, unless its ticket says why it is core. [value] is the
/// storage key and never changes once shipped: renaming it would read as "never
/// asked" and ask again.
enum Feature {
  /// Sets per muscle group on the body map, on the profile (#136).
  muscleMap('muscleMap');

  final String value;

  new(this.value);
}

/// What the user said about a [Feature].
///
/// Three answers rather than a bool, because "said no" and "never asked" have
/// to stay apart: only the second may ever be asked.
enum FeatureAnswer {
  /// Never offered. The feature is off, and the one ask is still to come.
  unasked,

  /// Offered and not answered. Off, and never asked again: leaving the offer
  /// unanswered counts as no. The offer stays up for the rest of the session
  /// it was first shown in, so a user who looks away and back can still take
  /// it.
  pending,
  on,
  off,
  ;

  static FeatureAnswer fromString(String? v) {
    return switch (v) {
      'pending' => pending,
      'on' => on,
      'off' => off,
      _ => unasked,
    };
  }
}
