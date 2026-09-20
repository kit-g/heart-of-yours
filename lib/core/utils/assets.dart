abstract final class Assets {
  // SVG
  static const String emptyWorkout = 'assets/svg/barbell.svg';
  static const String mobileUpgrade = 'assets/svg/mobile_upgrade.svg';

  // PNG

  /// The mark alone: the heart cropped to its own edges, on transparency.
  ///
  /// Not one of the `launcher_*` files, which are all inputs to the icon
  /// generator and shaped for it rather than for a page. `launcher_main_macos`
  /// — which this replaced — is the heart baked onto an *opaque white square*,
  /// because it is the source for the web favicon, where a ground is wanted.
  /// On a coloured surface that square is a white box around the mark, which
  /// is what the login screen's greeting pane showed on every tablet. The two
  /// transparent ones, `launcher_fg` and `launcher_main_mono`, carry Android's
  /// adaptive-icon safe area instead, so the heart covers under half the
  /// canvas and the empty rest has to be positioned around.
  ///
  /// It is a single colour, so tint it — `colorBlendMode: .srcIn` — rather
  /// than relying on the fill it happens to ship with.
  static const String heart = 'assets/icons/heart.png';
}
