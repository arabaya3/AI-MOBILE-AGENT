import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/config/app_config.dart';

AppConfig parse(AppEnvironment env, String url, {bool release = false}) =>
    AppConfig.parse(
      environment: env,
      rawApiBaseUrl: url,
      isReleaseBuild: release,
    );

void main() {
  group('dev (debug)', () {
    test('allows cleartext to local development hosts', () {
      for (final url in [
        'http://10.0.2.2:8001/api/v1',
        'http://localhost:8001/api/v1',
        'http://127.0.0.1:8001/api/v1',
        'http://192.168.1.20:8001/api/v1',
      ]) {
        expect(parse(AppEnvironment.dev, url).apiBaseUrl.toString(), url);
      }
    });

    test('rejects cleartext to public hosts, including raw public IPs', () {
      expect(
        () => parse(AppEnvironment.dev, 'http://87.106.87.218:8001/api/v1'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parse(AppEnvironment.dev, 'http://api.example.com/api/v1'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('normalizes a trailing slash', () {
      expect(
        parse(
          AppEnvironment.dev,
          'http://localhost:8001/api/v1/',
        ).apiBaseUrl.path,
        '/api/v1',
      );
    });
  });

  group('release safety', () {
    for (final env in AppEnvironment.values) {
      test('${env.name} release build refuses http', () {
        expect(
          () => parse(env, 'http://localhost:8001/api/v1', release: true),
          throwsA(isA<ConfigException>()),
        );
      });
    }

    for (final env in [AppEnvironment.staging, AppEnvironment.prod]) {
      test('${env.name} requires https even in debug', () {
        expect(
          () => parse(env, 'http://api.example.com/api/v1'),
          throwsA(isA<ConfigException>()),
        );
      });

      test('${env.name} rejects IP literals and local hosts over https', () {
        for (final url in [
          'https://87.106.87.218/api/v1',
          'https://[::1]/api/v1',
          'https://localhost/api/v1',
        ]) {
          expect(
            () => parse(env, url, release: true),
            throwsA(isA<ConfigException>()),
            reason: url,
          );
        }
      });

      test('${env.name} accepts an https host name', () {
        final config = parse(
          env,
          'https://api.example.com/api/v1',
          release: true,
        );
        expect(config.apiBaseUrl.scheme, 'https');
        expect(config.environment, env);
      });

      test('${env.name} fails when no URL is configured', () {
        expect(
          () => parse(env, '  ', release: true),
          throwsA(isA<ConfigException>()),
        );
      });
    }
  });

  test('rejects credentials, queries, fragments and other schemes', () {
    for (final url in [
      'https://user:pass@api.example.com/api/v1',
      'https://api.example.com/api/v1?x=1',
      'https://api.example.com/api/v1#frag',
      'ftp://api.example.com/api/v1',
      'api.example.com/api/v1',
    ]) {
      expect(
        () => parse(AppEnvironment.prod, url, release: true),
        throwsA(isA<ConfigException>()),
        reason: url,
      );
    }
  });
}
