import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions_platform_interface/quick_actions_platform_interface.dart';
import 'package:bankify/app_lock_policy.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/pages/login.dart';
import 'package:bankify/pages/settings.dart';
import 'package:bankify/pages/splash.dart';

class _FakeQuickActionsPlatform extends QuickActionsPlatform
    with MockPlatformInterfaceMixin {
  QuickActionHandler? handler;
  List<ShortcutItem>? shortcutItems;

  @override
  Future<void> clearShortcutItems() async {
    shortcutItems = <ShortcutItem>[];
  }

  @override
  Future<void> initialize(QuickActionHandler? handler) async {
    this.handler = handler;
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem>? items) async {
    shortcutItems = items;
  }
}

class _FakeFireflyService extends FireflyService {
  _FakeFireflyService({this.handleSignIn});

  final Future<bool> Function(String host, String apiKey, int attempt)?
  handleSignIn;

  int signInAttempts = 0;
  TrustedServerCertificate? trustedCertificate;
  String? _lastTriedHost;
  bool _signedIn = false;

  @override
  String? get lastTriedHost => _lastTriedHost;

  @override
  bool get signedIn => _signedIn;

  @override
  Object? get storageSignInException => null;

  @override
  Future<bool> signIn(String host, String apiKey) async {
    signInAttempts += 1;
    _lastTriedHost = host;
    final bool result =
        await handleSignIn?.call(host, apiKey, signInAttempts) ?? false;
    _signedIn = result;
    return result;
  }

  @override
  Future<void> trustServerCertificate(
    TrustedServerCertificate certificate,
  ) async {
    trustedCertificate = certificate;
  }
}

Widget _buildTestApp(Widget child, {FireflyService? fireflyService}) {
  final Widget app = MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: child,
  );

  if (fireflyService == null) {
    return app;
  }

  return ChangeNotifierProvider<FireflyService>.value(
    value: fireflyService,
    child: app,
  );
}

String _timeoutLabel(AppLockTimeout timeout) {
  return switch (timeout) {
    AppLockTimeout.immediate => 'Immediately',
    AppLockTimeout.oneMinute => '1 minute',
    AppLockTimeout.fiveMinutes => '5 minutes',
    AppLockTimeout.tenMinutes => '10 minutes',
    AppLockTimeout.thirtyMinutes => '30 minutes',
  };
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUp(() {
    QuickActionsPlatform.instance = _FakeQuickActionsPlatform();
  });

  testWidgets('login page defaults to https and obscures the api key', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_buildTestApp(const LoginPage()));

    final Finder editableFields = find.byType(EditableText);
    final EditableText hostField = tester.widget<EditableText>(
      editableFields.first,
    );
    final EditableText apiKeyField = tester.widget<EditableText>(
      editableFields.last,
    );

    expect(hostField.controller.text, 'https://');
    expect(apiKeyField.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    expect(
      tester.widget<EditableText>(editableFields.last).obscureText,
      isFalse,
    );
  });

  testWidgets('login page rejects public http hosts in debug builds', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_buildTestApp(const LoginPage()));

    await tester.enterText(
      find.byType(EditableText).first,
      'http://example.com',
    );
    await tester.enterText(find.byType(EditableText).last, 'secret-token');
    final Finder loginButton = find.widgetWithText(FilledButton, 'Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Only local HTTP hosts are allowed in debug builds.'),
      findsOneWidget,
    );
    expect(find.byType(SplashPage), findsNothing);
  });

  testWidgets(
    'splash page can trust a presented certificate and retry sign-in',
    (WidgetTester tester) async {
      _setLargeSurface(tester);
      final TrustedServerCertificate certificate = TrustedServerCertificate(
        authority: '192.168.1.6:8084',
        sha256Fingerprint: 'AA:BB:CC',
        subject: 'CN=bankify.local',
        issuer: 'CN=bankify.local',
        validFrom: DateTime.utc(2026, 1, 1),
        validTo: DateTime.utc(2027, 1, 1),
      );
      final _FakeFireflyService fireflyService = _FakeFireflyService(
        handleSignIn: (String host, String apiKey, int attempt) async {
          if (attempt == 1) {
            throw AuthErrorCertificateApprovalRequired(certificate);
          }
          return true;
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          const SplashPage(host: 'https://192.168.1.6:8084', apiKey: 'token'),
          fireflyService: fireflyService,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Trust certificate'), findsOneWidget);
      expect(find.textContaining('SHA-256: AA:BB:CC'), findsOneWidget);
      expect(
        find.textContaining('Host: https://192.168.1.6:8084'),
        findsOneWidget,
      );

      final Finder trustPageButton = find.widgetWithText(
        FilledButton,
        'Trust certificate',
      );
      tester.widget<FilledButton>(trustPageButton).onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Trust this certificate?'), findsOneWidget);
      expect(find.textContaining('Subject: CN=bankify.local'), findsWidgets);

      final Finder trustDialogButton = find.widgetWithText(
        FilledButton,
        'Trust certificate',
      );
      tester.widget<FilledButton>(trustDialogButton.last).onPressed!.call();
      await tester.pumpAndSettle();

      expect(fireflyService.signInAttempts, 2);
      expect(fireflyService.trustedCertificate, same(certificate));
    },
  );

  testWidgets('app lock timeout dialog returns the selected timeout', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    AppLockTimeout? selectedTimeout;

    await tester.pumpWidget(
      _buildTestApp(
        Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return FilledButton(
                onPressed: () async {
                  selectedTimeout = await showDialog<AppLockTimeout>(
                    context: context,
                    builder:
                        (BuildContext context) => const AppLockTimeoutDialog(
                          selectedTimeout: AppLockTimeout.oneMinute,
                          labelBuilder: _timeoutLabel,
                        ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Choose lock timeout'), findsOneWidget);
    expect(find.text('Immediately'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);

    await tester.tap(find.text('10 minutes'));
    await tester.pumpAndSettle();

    expect(selectedTimeout, AppLockTimeout.tenMinutes);
  });
}
