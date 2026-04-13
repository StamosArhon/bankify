import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;
import 'package:bankify/app_profile.dart';

class ProfileCacheStore {
  ProfileCacheStore({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  static const String _rootDirectoryName = 'profile_cache';

  Future<Directory> _resolveBaseDirectory() async {
    return _baseDirectory ?? await getApplicationSupportDirectory();
  }

  String _fileNameForKey(String key) {
    return "${base64Url.encode(utf8.encode(key))}.json";
  }

  Future<Directory> _resolveProfileDirectory(AppProfile profile) async {
    final Directory baseDirectory = await _resolveBaseDirectory();
    final Directory directory = Directory.fromUri(
      baseDirectory.uri.resolve("$_rootDirectoryName/${profile.id}/"),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _resolveCacheFile(AppProfile profile, String key) async {
    final Directory directory = await _resolveProfileDirectory(profile);
    return File.fromUri(directory.uri.resolve(_fileNameForKey(key)));
  }

  Future<T?> readJson<T>(
    AppProfile profile,
    String key,
    T Function(Object? json) decoder,
  ) async {
    final File file = await _resolveCacheFile(profile, key);
    if (!await file.exists()) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      return decoder(decoded);
    } on FormatException {
      try {
        await file.delete();
      } catch (_) {}
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> writeJson(AppProfile profile, String key, Object? value) async {
    final File file = await _resolveCacheFile(profile, key);
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  Future<void> clearProfile(AppProfile profile) async {
    final Directory directory = await _resolveProfileDirectory(profile);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class ProfileCachedLoader {
  const ProfileCachedLoader({required this.profile, required this.cacheStore});

  final AppProfile profile;
  final ProfileCacheStore cacheStore;

  Future<T> load<T>({
    required String key,
    required Future<T> Function() fetch,
    required Object? Function(T value) encode,
    required T Function(Object? json) decode,
  }) async {
    try {
      final T value = await fetch();
      try {
        await cacheStore.writeJson(profile, key, encode(value));
      } catch (_) {
        // Cache writes are best effort. A successful network fetch should win.
      }
      return value;
    } catch (_) {
      final T? cached = await cacheStore.readJson(profile, key, decode);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }
}
