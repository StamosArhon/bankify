import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppProfile {
  const AppProfile({required this.id, required this.host});

  final String id;
  final String host;

  factory AppProfile.fromCredentials({
    required String host,
    required String apiKey,
  }) {
    final String normalizedHost = host.trim();
    final String hash =
        sha256
            .convert(utf8.encode("$normalizedHost\n${apiKey.trim()}"))
            .toString();
    return AppProfile(id: hash.substring(0, 24), host: normalizedHost);
  }

  @override
  bool operator ==(Object other) {
    return other is AppProfile && other.id == id && other.host == host;
  }

  @override
  int get hashCode => Object.hash(id, host);

  @override
  String toString() => "AppProfile(id: $id, host: $host)";
}
