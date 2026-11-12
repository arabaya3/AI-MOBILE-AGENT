import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/config/app_config.dart';

/// The same cases run in the Gradle check (verifyReleaseConfigRules) and tool/check_release_config.py.
void main() {
  final cases =
      (jsonDecode(File('config/release_url_cases.json').readAsStringSync())
              as Map<String, dynamic>)['cases']
          as List<dynamic>;

  for (final raw in cases) {
    final c = raw as Map<String, dynamic>;
    final url = c['url'] as String;
    final valid = c['valid'] as bool;
    for (final env in [AppEnvironment.staging, AppEnvironment.prod]) {
      test(
        '${env.name} release: "$url" is ${valid ? 'accepted' : 'refused'}',
        () {
          AppConfig parse() => AppConfig.parse(
            environment: env,
            rawApiBaseUrl: url,
            isReleaseBuild: true,
          );
          if (valid) {
            expect(parse().apiBaseUrl.scheme, 'https');
          } else {
            expect(parse, throwsA(isA<ConfigException>()));
          }
        },
      );
    }
  }

  test('link hosts follow the same host rule', () {
    for (final host in [
      '-bad.example.com',
      'api_bad.example.com',
      'intranet',
    ]) {
      expect(
        () => AppConfig.parse(
          environment: AppEnvironment.prod,
          rawApiBaseUrl: 'https://api.example.com/api/v1',
          isReleaseBuild: true,
          rawLinkHosts: host,
        ),
        throwsA(isA<ConfigException>()),
        reason: host,
      );
    }
  });
}
