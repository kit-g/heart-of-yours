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

  static const String accountDeletionDeadline = String.fromEnvironment('ACCOUNT_DELETION_DEADLINE');
  static const String api = String.fromEnvironment('API');
  static const String appLink = String.fromEnvironment('APP_LINK');
  static const String appName = String.fromEnvironment('APP_NAME');
  static Env env = Env.fromString(const String.fromEnvironment('ENV').trim());
  static const String logLevel = String.fromEnvironment('LOG_LEVEL');
  static const String mediaLink = String.fromEnvironment('MEDIA_LINK');
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String themeColorHex = String.fromEnvironment('DEFAULT_THEME_COLOR');

  static bool get isProd => env == Env.prod;
}
