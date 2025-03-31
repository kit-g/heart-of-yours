import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef Package = ({String appName, String version, String build});

class AppInfo with ChangeNotifier {
  late Package _package;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  AppInfo({this.onError});

  static AppInfo of(BuildContext context) {
    return Provider.of<AppInfo>(context, listen: false);
  }

  String get appName => _package.appName;

  String get version => _package.version;

  String get build => _package.build;

  String get fullVersion => '${_package.version}+${_package.build}';

  Future<void> init(Future<Package> Function() initializer) async {
    try {
      _package = await initializer();
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }
}
