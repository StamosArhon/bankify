import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/app_profile.dart';
import 'package:bankify/profile_cache_store.dart';

void main() {
  test(
    'ProfileCacheStore writes, reads, and clears per-profile data',
    () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'bankify-cache-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final AppProfile profile = AppProfile.fromCredentials(
        host: 'https://bankify.example.com',
        apiKey: 'secret-token',
      );
      final ProfileCacheStore cacheStore = ProfileCacheStore(
        baseDirectory: tempDir,
      );

      await cacheStore.writeJson(
        profile,
        'accounts:asset:1:50',
        <String, dynamic>{'count': 3},
      );

      final Map<String, dynamic>? cached = await cacheStore.readJson(
        profile,
        'accounts:asset:1:50',
        (Object? json) => json! as Map<String, dynamic>,
      );
      expect(cached, containsPair('count', 3));

      await cacheStore.clearProfile(profile);

      final Object? afterClear = await cacheStore.readJson(
        profile,
        'accounts:asset:1:50',
        (Object? json) => json!,
      );
      expect(afterClear, isNull);
    },
  );

  test(
    'ProfileCachedLoader falls back to cached data when fetch fails',
    () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'bankify-loader-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final AppProfile profile = AppProfile.fromCredentials(
        host: 'https://bankify.example.com',
        apiKey: 'secret-token',
      );
      final ProfileCacheStore cacheStore = ProfileCacheStore(
        baseDirectory: tempDir,
      );
      final ProfileCachedLoader loader = ProfileCachedLoader(
        profile: profile,
        cacheStore: cacheStore,
      );

      final String freshValue = await loader.load<String>(
        key: 'dashboard:last-days',
        fetch: () async => 'fresh',
        encode: (String value) => <String, dynamic>{'value': value},
        decode:
            (Object? json) =>
                (json! as Map<String, dynamic>)['value'] as String,
      );
      expect(freshValue, 'fresh');

      final String cachedValue = await loader.load<String>(
        key: 'dashboard:last-days',
        fetch: () async => throw Exception('offline'),
        encode: (String value) => <String, dynamic>{'value': value},
        decode:
            (Object? json) =>
                (json! as Map<String, dynamic>)['value'] as String,
      );
      expect(cachedValue, 'fresh');
    },
  );
}
