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
}
