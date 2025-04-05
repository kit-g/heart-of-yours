enum Env {
  dev,
  prod;

  factory Env.fromString(String? v) {
    return switch (v) {
      'dev' || 'd' || 'development' => dev,
      'prod' || 'p' || 'production' => prod,
      _ => throw UnimplementedError('Valid environments are: ${Env.values}'),
    };
  }
}

/// App config is fetched from the environment
/// implying that it is run/built with `--dart-define(-from-file)`
class AppConfig {
  const AppConfig._();

  static const accountDeletionDeadline = String.fromEnvironment('ACCOUNT_DELETION_DEADLINE');
  static const api = String.fromEnvironment('API');
  static const _appLink = String.fromEnvironment('APP_LINK');
  static const appName = String.fromEnvironment('APP_NAME');
  static final env = Env.fromString(const String.fromEnvironment('ENV').trim());
  static const logLevel = String.fromEnvironment('LOG_LEVEL');
  static const _mediaLink = String.fromEnvironment('MEDIA_LINK');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const themeColorHex = String.fromEnvironment('DEFAULT_THEME_COLOR');

  static bool get isProd => env == Env.prod;

  static String get appLink => Uri.https(_appLink).toString();

  static String get mediaLink => Uri.https(_mediaLink).toString();

  static String get avatarLink => Uri.https(_mediaLink, 'avatars').toString();
}
