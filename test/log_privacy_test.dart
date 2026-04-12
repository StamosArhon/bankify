import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:bankify/log_privacy.dart';

void main() {
  group('sanitizeLogText', () {
    test('redacts urls, hosts, paths, and bearer tokens', () {
      final String sanitized = sanitizeLogText(
        'Host https://192.168.1.6:8084/api/v1/about '
        'token Bearer abc123+/= '
        'win C:\\Users\\stama\\AppData\\Local\\Temp\\debuglog.txt '
        'unix /data/user/0/io.github.stamosarhon.bankify/cache/debuglog.txt',
      );

      expect(sanitized, isNot(contains('192.168.1.6')));
      expect(sanitized, contains('[redacted-url]'));
      expect(sanitized, contains('Bearer [redacted]'));
      expect(
        RegExp(r'\[redacted-path\]').allMatches(sanitized).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('redacts api key assignments', () {
      final String sanitized = sanitizeLogText(
        'apiKey=super-secret-value authorization: Bearer abc123',
      );

      expect(sanitized, contains('apiKey=[redacted]'));
      expect(sanitized, contains('authorization: [redacted]'));
    });
  });

  group('computeRootLogLevel', () {
    test('uses warning level for normal release usage', () {
      expect(
        computeRootLogLevel(
          debugLoggingEnabled: false,
          isDebugBuild: false,
        ),
        Level.WARNING,
      );
    });

    test('uses verbose logging for debug builds or explicit debug logging', () {
      expect(
        computeRootLogLevel(
          debugLoggingEnabled: false,
          isDebugBuild: true,
        ),
        Level.ALL,
      );
      expect(
        computeRootLogLevel(
          debugLoggingEnabled: true,
          isDebugBuild: false,
        ),
        Level.ALL,
      );
    });
  });
}
