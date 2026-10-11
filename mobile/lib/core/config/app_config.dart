import 'dart:io' show InternetAddress, InternetAddressType;

enum AppEnvironment { dev, staging, prod }

class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

class AppConfig {
  const AppConfig._({required this.environment, required this.apiBaseUrl});

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  bool get isDev => environment == AppEnvironment.dev;

  static const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

  /// Reads `API_BASE_URL` supplied via `--dart-define-from-file=config/<env>.json`.
  factory AppConfig.fromEnvironment(
    AppEnvironment environment, {
    required bool isReleaseBuild,
  }) => AppConfig.parse(
    environment: environment,
    rawApiBaseUrl: _apiBaseUrlDefine,
    isReleaseBuild: isReleaseBuild,
  );

  factory AppConfig.parse({
    required AppEnvironment environment,
    required String rawApiBaseUrl,
    required bool isReleaseBuild,
  }) {
    final raw = rawApiBaseUrl.trim();
    if (raw.isEmpty) {
      throw ConfigException('API_BASE_URL is not set for ${environment.name}.');
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ConfigException('API_BASE_URL must be an absolute URL.');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const ConfigException(
        'API_BASE_URL must not contain credentials, a query or a fragment.',
      );
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const ConfigException('API_BASE_URL must use http or https.');
    }

    final secureRequired = environment != AppEnvironment.dev || isReleaseBuild;
    if (secureRequired) {
      if (uri.scheme != 'https') {
        throw ConfigException(
          '${environment.name} builds require an https API_BASE_URL.',
        );
      }
      if (_isIpLiteral(uri.host) || _isLocalHost(uri.host)) {
        throw ConfigException(
          '${environment.name} builds require a public host name, not an IP or local address.',
        );
      }
    } else if (uri.scheme == 'http' && !_isLocalDevelopmentHost(uri.host)) {
      throw const ConfigException(
        'Cleartext http is only allowed for local development hosts.',
      );
    }

    final normalizedPath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return AppConfig._(
      environment: environment,
      apiBaseUrl: uri.replace(path: normalizedPath),
    );
  }

  static bool _isIpLiteral(String host) =>
      InternetAddress.tryParse(host) != null;

  static bool _isLocalHost(String host) =>
      host == 'localhost' || host.endsWith('.localhost');

  static bool _isLocalDevelopmentHost(String host) {
    if (_isLocalHost(host) || host == '10.0.2.2') return true;
    final address = InternetAddress.tryParse(host);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return address?.isLoopback ?? false;
    }
    final b = address.rawAddress;
    return b[0] == 127 ||
        b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }
}
