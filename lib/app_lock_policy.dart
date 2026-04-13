enum AppLockTimeout {
  immediate(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  tenMinutes(Duration(minutes: 10)),
  thirtyMinutes(Duration(minutes: 30));

  const AppLockTimeout(this.duration);

  final Duration duration;
}

const AppLockTimeout defaultAppLockTimeout = AppLockTimeout.oneMinute;
const AppLockTimeout legacyAppLockTimeout = AppLockTimeout.tenMinutes;

AppLockTimeout resolveStoredAppLockTimeout(
  int? index, {
  required bool lockEnabled,
}) {
  if (index != null && index >= 0 && index < AppLockTimeout.values.length) {
    return AppLockTimeout.values[index];
  }
  return lockEnabled ? legacyAppLockTimeout : defaultAppLockTimeout;
}

bool shouldRequireAppUnlock({
  required DateTime? lastPausedAt,
  required AppLockTimeout timeout,
  DateTime? now,
}) {
  if (lastPausedAt == null) {
    return false;
  }

  if (timeout.duration == Duration.zero) {
    return true;
  }

  final DateTime cutoff = (now ?? DateTime.now()).subtract(timeout.duration);
  return !lastPausedAt.isAfter(cutoff);
}

DateTime forceExpiredAppLockTimestamp() {
  return DateTime.fromMillisecondsSinceEpoch(0);
}
