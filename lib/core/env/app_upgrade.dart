class AppVersionSentry {
  static final AppVersionSentry instance = AppVersionSentry._();

  new _();

  bool _upgradeRequired = false;

  bool get upgradeRequired => _upgradeRequired;

  void requireUpgrade() {
    _upgradeRequired = true;
  }
}
