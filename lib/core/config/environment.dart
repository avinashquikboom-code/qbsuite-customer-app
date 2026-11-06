import 'package:flutter/foundation.dart';

enum AppEnvironment { development, staging, production }

abstract final class Environment {
  static const name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static AppEnvironment get current => AppEnvironment.values.byName(name);
  static void validate({bool requireUrl = false, String? baseUrl}) {
    final env = current;
    final value = baseUrl ?? apiBaseUrl;
    if (value.isEmpty && !requireUrl) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        ((env != AppEnvironment.development || kReleaseMode) &&
            uri.scheme != 'https')) {
      throw const FormatException(
        'Set a valid API_BASE_URL; HTTPS is required for staging, production and release builds.',
      );
    }
  }
}
