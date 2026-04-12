import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final RegExp _urlPattern = RegExp(
  r'\bhttps?:\/\/[^\s)\]>]+',
  caseSensitive: false,
);
final RegExp _ipv4HostPattern = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?\b');
final RegExp _bearerTokenPattern = RegExp(
  r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
  caseSensitive: false,
);
final RegExp _apiKeyPattern = RegExp(
  r'((?:api[_ -]?key|authorization)\s*[:=]\s*)([^\s,;]+)',
  caseSensitive: false,
);
final RegExp _windowsPathPattern = RegExp(
  r'(?:(?:[A-Za-z]:\\)|(?:\\\\))[^\s<>:"|?*]+(?:\\[^\s<>:"|?*]+)*',
);
final RegExp _unixPathPattern = RegExp(
  r'(?<![:\w])/(?:[^/\s]+/)+[^/\s]+',
);

Level computeRootLogLevel({
  required bool debugLoggingEnabled,
  bool isDebugBuild = kDebugMode,
}) => (isDebugBuild || debugLoggingEnabled) ? Level.ALL : Level.WARNING;

String sanitizeLogText(String value) {
  String sanitized = value;
  sanitized = sanitized.replaceAllMapped(
    _bearerTokenPattern,
    (_) => 'Bearer [redacted]',
  );
  sanitized = sanitized.replaceAllMapped(
    _apiKeyPattern,
    (Match match) => '${match.group(1)}[redacted]',
  );
  sanitized = sanitized.replaceAll(_urlPattern, '[redacted-url]');
  sanitized = sanitized.replaceAll(_ipv4HostPattern, '[redacted-host]');
  sanitized = sanitized.replaceAll(_windowsPathPattern, '[redacted-path]');
  sanitized = sanitized.replaceAll(_unixPathPattern, '[redacted-path]');
  return sanitized;
}

Object? sanitizeLogObject(Object? value) {
  if (value == null) {
    return null;
  }
  return sanitizeLogText(value.toString());
}

StackTrace? sanitizeLogStackTrace(StackTrace? stackTrace) {
  if (stackTrace == null) {
    return null;
  }
  final String original = stackTrace.toString();
  final String sanitized = sanitizeLogText(original);
  if (sanitized == original) {
    return stackTrace;
  }
  return StackTrace.fromString(sanitized);
}
