import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/auth.dart';

void main() {
  group('transport policy', () {
    test('supports https hosts', () {
      expect(isSupportedFireflyUri(Uri.parse('https://example.com')), isTrue);
    });

    test('allows local http hosts in debug and test builds', () {
      expect(
        allowsLocalDevelopmentHttpUri(Uri.parse('http://192.168.1.6:8084')),
        isTrue,
      );
      expect(
        allowsLocalDevelopmentHttpUri(Uri.parse('http://10.0.2.2:8080')),
        isTrue,
      );
      expect(
        allowsLocalDevelopmentHttpUri(Uri.parse('http://localhost')),
        isTrue,
      );
    });

    test('rejects public http hosts', () {
      expect(
        allowsLocalDevelopmentHttpUri(Uri.parse('http://example.com')),
        isFalse,
      );
      expect(isSupportedFireflyUri(Uri.parse('http://example.com')), isFalse);
    });

    test('recognizes local development hosts', () {
      expect(isLocalDevelopmentHost('localhost'), isTrue);
      expect(isLocalDevelopmentHost('127.0.0.1'), isTrue);
      expect(isLocalDevelopmentHost('192.168.1.6'), isTrue);
      expect(isLocalDevelopmentHost('172.20.1.5'), isTrue);
      expect(isLocalDevelopmentHost('10.0.2.2'), isTrue);
      expect(isLocalDevelopmentHost('8.8.8.8'), isFalse);
      expect(isLocalDevelopmentHost('example.com'), isFalse);
    });
  });
}
