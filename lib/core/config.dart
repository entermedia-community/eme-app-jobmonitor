/// Build-time configuration. Nothing secret is hardcoded:
///
///   flutter run -d chrome --dart-define=EME_BASE_URL=http://localhost:8080
///
/// Users sign in with an emailed code; the browser then holds a signing key (see core/auth).
class AppConfig {
  static const emeBaseUrl = String.fromEnvironment(
    'EME_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// EME application folder that serves /services/* (e.g. /site/mediadb).
  static const emeAppPath = String.fromEnvironment(
    'EME_APP_PATH',
    defaultValue: '/site/mediadb',
  );

  /// Optional dev-only bearer token; normal use is the key signature.
  static const emeToken = String.fromEnvironment('EME_TOKEN');
}
