import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/settings.dart';

class _FakeAuthSecureStorage implements AuthSecureStorage {
  _FakeAuthSecureStorage([Map<String, String>? initialValues])
    : values = <String, String>{...?initialValues};

  final Map<String, String> values;
  final List<String> deletedKeys = <String>[];

  @override
  Future<void> delete({required String key}) async {
    deletedKeys.add(key);
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      values.remove(key);
      return;
    }
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'signOut clears only persisted auth secrets and preserves prefs',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SettingsProvider.settingTheme: SettingsProvider.settingThemeDark,
        SettingsProvider.settingLockTimeout: 1,
      });
      final _FakeAuthSecureStorage storage =
          _FakeAuthSecureStorage(<String, String>{
            FireflyService.storageApiHost: 'https://bankify.local',
            FireflyService.storageApiKey: 'secret-token',
            FireflyService.storageTlsAuthority: 'bankify.local:443',
            FireflyService.storageTlsFingerprint: 'AA:BB:CC',
            FireflyService.storageTlsSubject: 'CN=bankify.local',
            FireflyService.storageTlsIssuer: 'CN=bankify.local',
            FireflyService.storageTlsValidFrom:
                DateTime.utc(2026, 1, 1).toIso8601String(),
            FireflyService.storageTlsValidTo:
                DateTime.utc(2027, 1, 1).toIso8601String(),
            'non_auth_secure_value': 'keep-me',
          });

      final FireflyService service = FireflyService(storage: storage);
      await service.signOut();

      expect(
        storage.deletedKeys,
        unorderedEquals(FireflyService.persistedSessionSecretKeys),
      );
      expect(storage.values, containsPair('non_auth_secure_value', 'keep-me'));
      expect(
        storage.values.keys,
        isNot(contains(anyOf(FireflyService.persistedSessionSecretKeys))),
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SettingsProvider.settingTheme),
        SettingsProvider.settingThemeDark,
      );
      expect(prefs.getInt(SettingsProvider.settingLockTimeout), 1);
    },
  );

  test(
    'signOut removes persisted credentials used for storage sign-in',
    () async {
      final _FakeAuthSecureStorage storage =
          _FakeAuthSecureStorage(<String, String>{
            FireflyService.storageApiHost: 'https://bankify.local',
            FireflyService.storageApiKey: 'secret-token',
          });

      final FireflyService service = FireflyService(storage: storage);
      await service.signOut();

      expect(await service.signInFromStorage(), isFalse);
    },
  );
}
