class AppVersionSentry {
  static final AppVersionSentry instance = AppVersionSentry._();

  AppVersionSentry._();

  bool _upgradeRequired = false;

  bool get upgradeRequired => _upgradeRequired;

  void requireUpgrade() {
    _upgradeRequired = true;
  }
}
