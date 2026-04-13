import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/pages/login.dart';

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
      expect(isLocalDevelopmentHost('::1'), isTrue);
      expect(isLocalDevelopmentHost('192.168.1.6'), isTrue);
      expect(isLocalDevelopmentHost('172.20.1.5'), isTrue);
      expect(isLocalDevelopmentHost('10.0.2.2'), isTrue);
      expect(isLocalDevelopmentHost('fe80::1'), isTrue);
      expect(isLocalDevelopmentHost('fd12:3456:789a::1'), isTrue);
      expect(isLocalDevelopmentHost('8.8.8.8'), isFalse);
      expect(isLocalDevelopmentHost('2001:4860:4860::8888'), isFalse);
      expect(isLocalDevelopmentHost('example.com'), isFalse);
    });

    test('normalizes bare hosts to https and keeps explicit schemes', () {
      expect(
        UriScheme.normalize('192.168.1.6:8084'),
        'https://192.168.1.6:8084',
      );
      expect(
        UriScheme.normalize(' https://demo.firefly-iii.org '),
        'https://demo.firefly-iii.org',
      );
      expect(
        UriScheme.normalize('http://127.0.0.1:8080'),
        'http://127.0.0.1:8080',
      );
    });

    test('validates local ipv6 http hosts but rejects public ones', () {
      expect(UriScheme.valid('http://[::1]:8080'), isTrue);
      expect(UriScheme.valid('http://[fd12:3456:789a::1]:8080'), isTrue);
      expect(UriScheme.valid('http://[2001:4860:4860::8888]:8080'), isFalse);
    });

    test('classifies likely plain-http-over-https handshake failures', () {
      expect(
        isLikelyPlainHttpOverHttpsError(Exception('WRONG_VERSION_NUMBER')),
        isTrue,
      );
      expect(
        isLikelyPlainHttpOverHttpsError(Exception('packet length too long')),
        isTrue,
      );
      expect(
        isLikelyPlainHttpOverHttpsError(Exception('certificate verify failed')),
        isFalse,
      );
    });

    test('builds stable tls authorities for default and explicit ports', () {
      expect(
        tlsAuthorityForUri(Uri.parse('https://Example.com')),
        'example.com:443',
      );
      expect(
        tlsAuthorityForUri(Uri.parse('https://Example.com:8443/path')),
        'example.com:8443',
      );
      expect(tlsAuthorityForUri(Uri.parse('http://127.0.0.1')), '127.0.0.1:80');
    });

    test(
      'diagnoses certificate approval and https protocol mismatch errors',
      () {
        final TrustedServerCertificate certificate = TrustedServerCertificate(
          authority: '192.168.1.6:8084',
          sha256Fingerprint: 'AA:BB:CC',
          subject: 'CN=bankify.local',
          issuer: 'CN=bankify.local',
          validFrom: DateTime.utc(2026, 1, 1),
          validTo: DateTime.utc(2027, 1, 1),
        );

        final ConnectionFailureDetails approvalDiagnosis =
            diagnoseConnectionFailure(
              AuthErrorCertificateApprovalRequired(certificate),
              host: 'https://192.168.1.6:8084',
            );
        final ConnectionFailureDetails protocolDiagnosis =
            diagnoseConnectionFailure(
              const AuthErrorInvalidHttpsEndpoint(),
              host: 'https://192.168.1.6:8084',
            );

        expect(
          approvalDiagnosis.kind,
          ConnectionFailureKind.certificateApprovalRequired,
        );
        expect(approvalDiagnosis.canTrustPresentedCertificate, isTrue);
        expect(approvalDiagnosis.certificate, same(certificate));

        expect(
          protocolDiagnosis.kind,
          ConnectionFailureKind.invalidHttpsEndpoint,
        );
        expect(protocolDiagnosis.canTrustPresentedCertificate, isFalse);
      },
    );

    test('diagnoses status, version, and network failures', () {
      expect(
        diagnoseConnectionFailure(
          const AuthErrorStatusCode(401),
          host: 'https://firefly.example.com',
        ).kind,
        ConnectionFailureKind.unexpectedStatusCode,
      );
      expect(
        diagnoseConnectionFailure(
          AuthErrorVersionTooLow(minApiVersion),
        ).requiredVersion,
        minApiVersion,
      );
      expect(
        diagnoseConnectionFailure(Exception('boom')).kind,
        ConnectionFailureKind.unknown,
      );
    });
  });
}
