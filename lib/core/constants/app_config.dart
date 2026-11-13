/// Global Application Configuration for QuikBoom CRM Mobile.
class AppConfig {
  /// Set to [true] for UI-only / Demo Mode.
  /// - Zero backend HTTP/API requests are made.
  /// - Fast local state updates with realistic corporate data.
  /// - No network error loops or timeouts.
  ///
  /// Set to [false] to connect to live NestJS / PostgreSQL backend.
  static const bool uiOnlyMode = false;

  /// Application environment identifier
  static const String appName = 'QB Suite Customer';
  static const String appVersion = '1.0.0+1';
}
