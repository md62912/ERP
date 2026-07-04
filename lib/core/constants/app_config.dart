/// Supabase project configuration.
///
/// These values are safe to ship in a mobile client: the anon/publishable
/// key only grants what your Row Level Security policies allow.
/// For production, prefer loading these via --dart-define instead of
/// hardcoding, so different builds (dev/staging/prod) can point at
/// different projects.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hbzzvttszanbecmdmuce.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'sb_publishable_6-IOiefMcUngPT7fNmRK9w_oH1Gn0-T',
  );

  /// Used as the password-reset redirect target on native platforms
  /// (Android/iOS), where there's no browser `Uri.base` to read from.
  /// On web, the actual current origin is used instead (see
  /// ForgotPasswordScreen) so this only matters for mobile builds.
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://md62912.github.io/ERP/',
  );
}
