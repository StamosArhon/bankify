import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/app_lock_policy.dart';

void main() {
  group('app lock policy', () {
    test(
      'uses legacy timeout for existing locked installs without a saved value',
      () {
        expect(
          resolveStoredAppLockTimeout(null, lockEnabled: true),
          legacyAppLockTimeout,
        );
      },
    );

    test(
      'uses conservative default timeout when lock is disabled and no saved value exists',
      () {
        expect(
          resolveStoredAppLockTimeout(null, lockEnabled: false),
          defaultAppLockTimeout,
        );
      },
    );

    test('restores valid stored timeout values', () {
      expect(
        resolveStoredAppLockTimeout(
          AppLockTimeout.thirtyMinutes.index,
          lockEnabled: true,
        ),
        AppLockTimeout.thirtyMinutes,
      );
    });

    test('requires unlock immediately when configured to do so', () {
      expect(
        shouldRequireAppUnlock(
          lastPausedAt: DateTime.utc(2026, 4, 13, 12),
          timeout: AppLockTimeout.immediate,
          now: DateTime.utc(2026, 4, 13, 12, 0, 1),
        ),
        isTrue,
      );
    });

    test('respects timeout thresholds conservatively', () {
      final DateTime pausedAt = DateTime.utc(2026, 4, 13, 12, 0, 0);

      expect(
        shouldRequireAppUnlock(
          lastPausedAt: pausedAt,
          timeout: AppLockTimeout.fiveMinutes,
          now: DateTime.utc(2026, 4, 13, 12, 4, 59),
        ),
        isFalse,
      );
      expect(
        shouldRequireAppUnlock(
          lastPausedAt: pausedAt,
          timeout: AppLockTimeout.fiveMinutes,
          now: DateTime.utc(2026, 4, 13, 12, 5, 0),
        ),
        isTrue,
      );
    });
  });
}
