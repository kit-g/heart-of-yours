import 'package:flutter/material.dart';
import 'package:heart_state/heart_state.dart';

enum Env {
  dev,
  test,
  prod;

  factory Env.fromString(String? v) {
    return switch (v) {
      'dev' || 'd' || 'development' => dev,
      'prod' || 'p' || 'production' => prod,
      't' || 'test' || 'testing' => test,
      _ => throw UnimplementedError('Valid environments are: ${Env.values}'),
    };
  }
}

/// App config is fetched from the environment
/// implying that it is run/built with `--dart-define(-from-file)`
class AppConfig {
  const AppConfig._({
    required this.accountDeletionDeadline,
    this.allowsFeedbackFeature = true,
    required this.api,
    required this.appName,
    required this.env,
    required this.logLevel,
    required this.maxTemplates,
    required this.sentryDsn,
    required this.themeColorHex,
    required String appLink,
    required String mediaLink,
    required String testUserCredentials,
  }) : _appLink = appLink,
       _mediaLink = mediaLink,
       _testUserCredentials = testUserCredentials;

  final String accountDeletionDeadline;
  final String api;
  final String appName;
  final Env env;
  final String logLevel;
  final int maxTemplates;
  final String sentryDsn;
  final String themeColorHex;
  final String _appLink;
  final String _mediaLink;
  final String _testUserCredentials;
  final bool allowsFeedbackFeature;

  factory AppConfig.fromDartDefine() {
    return AppConfig._(
      accountDeletionDeadline: const String.fromEnvironment('ACCOUNT_DELETION_DEADLINE'),
      api: const String.fromEnvironment('API'),
      appName: const String.fromEnvironment('APP_NAME'),
      env: Env.fromString(const String.fromEnvironment('ENV').trim()),
      logLevel: const String.fromEnvironment('LOG_LEVEL'),
      maxTemplates: const int.fromEnvironment('MAX_TEMPLATES', defaultValue: 6),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      themeColorHex: const String.fromEnvironment('DEFAULT_THEME_COLOR'),
      appLink: const String.fromEnvironment('APP_LINK'),
      mediaLink: const String.fromEnvironment('MEDIA_LINK'),
      testUserCredentials: const String.fromEnvironment('TEST_USER_CREDENTIALS', defaultValue: ''),
    );
  }

  factory AppConfig.test({
    String accountDeletionDeadline = '2',
    String api = '',
    String appName = 'Heart',
    Env env = Env.dev,
    String logLevel = 'ALL',
    int maxTemplates = 6,
    String sentryDsn = '',
    String themeColorHex = '',
    String appLink = '',
    String mediaLink = '',
    String testUserCredentials = '',
    bool allowsFeedbackFeature = false,
  }) {
    return AppConfig._(
      accountDeletionDeadline: accountDeletionDeadline,
      api: api,
      appName: appName,
      env: env,
      logLevel: logLevel,
      maxTemplates: maxTemplates,
      sentryDsn: sentryDsn,
      themeColorHex: themeColorHex,
      appLink: appLink,
      mediaLink: mediaLink,
      testUserCredentials: testUserCredentials,
      allowsFeedbackFeature: allowsFeedbackFeature,
    );
  }

  static AppConfig of(BuildContext context) {
    return Provider.of<AppConfig>(context, listen: false);
  }

  bool get isProd => env == Env.prod;

  bool get isDev => env == Env.dev;

  String get appLink => Uri.https(_appLink).toString();

  String get mediaLink => _mediaLink;

  String get avatarLink => Uri.https(_mediaLink, 'avatars').toString();

  String get configLink => Uri.https(_mediaLink, 'config').toString();

  String get testUserEmail => switch (_testUserCredentials.split(':')) {
    [String username, String _] => username,
    _ => '',
  };

  String get testUserPassword => switch (_testUserCredentials.split(':')) {
    [String _, String password] => password,
    _ => '',
  };
}
