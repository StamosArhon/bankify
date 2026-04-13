import 'package:bankify/app_lock_policy.dart';
import 'package:bankify/app_session_state.dart';
import 'package:bankify/notificationlistener.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLaunchRequest', () {
    test('routes notification, quick action, and shared files to composer', () {
      final NotificationTransaction notification = NotificationTransaction(
        'com.example.app',
        'Payment',
        'Lunch',
        DateTime.utc(2026, 4, 13, 12),
      );
      final SharedFile sharedFile = SharedFile(
        value: 'file:///tmp/receipt.png',
        type: SharedMediaType.IMAGE,
      );

      expect(const AppLaunchRequest().opensTransactionComposer, isFalse);
      expect(const AppLaunchRequest().isEmpty, isTrue);

      expect(
        AppLaunchRequest(notification: notification).opensTransactionComposer,
        isTrue,
      );
      expect(
        const AppLaunchRequest(
          quickActionType: transactionAddQuickActionType,
        ).opensTransactionComposer,
        isTrue,
      );
      expect(
        const AppLaunchRequest(
          quickActionType: 'unrelated_action',
        ).opensTransactionComposer,
        isFalse,
      );
      expect(
        AppLaunchRequest(
          sharedFiles: <SharedFile>[sharedFile],
        ).opensTransactionComposer,
        isTrue,
      );
      expect(
        const AppLaunchRequest(sharedFiles: <SharedFile>[]).hasSharedFiles,
        isFalse,
      );
    });
  });

  group('AppSessionState', () {
    test(
      'resolves splash, login, and navigation from startup and auth state',
      () {
        const AppSessionState waiting = AppSessionState();
        expect(
          waiting.resolveHome(signedIn: true, hasStorageSignInException: false),
          AppHomeDestination.splash,
        );

        const AppSessionState lockedButReady = AppSessionState(
          startupPhase: AppStartupPhase.ready,
          unlockSatisfied: false,
        );
        expect(
          lockedButReady.resolveHome(
            signedIn: true,
            hasStorageSignInException: false,
          ),
          AppHomeDestination.splash,
        );

        const AppSessionState ready = AppSessionState(
          startupPhase: AppStartupPhase.ready,
          unlockSatisfied: true,
        );
        expect(
          ready.resolveHome(signedIn: false, hasStorageSignInException: false),
          AppHomeDestination.login,
        );
        expect(
          ready.resolveHome(signedIn: true, hasStorageSignInException: false),
          AppHomeDestination.navigation,
        );
        expect(
          ready.resolveHome(signedIn: true, hasStorageSignInException: true),
          AppHomeDestination.splash,
        );
      },
    );

    test('requires unlock on resume only when lock timeout has elapsed', () {
      expect(
        AppSessionState(
          lockEnabled: false,
          lastPausedAt: DateTime.utc(2026, 4, 13, 11, 0, 0),
        ).shouldRequireUnlockOnResume,
        isFalse,
      );

      expect(
        AppSessionState(
          lockEnabled: true,
          lockTimeout: AppLockTimeout.thirtyMinutes,
          lastPausedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ).shouldRequireUnlockOnResume,
        isFalse,
      );
      expect(
        AppSessionState(
          lockEnabled: true,
          lockTimeout: AppLockTimeout.immediate,
          lastPausedAt: forceExpiredAppLockTimestamp(),
        ).shouldRequireUnlockOnResume,
        isTrue,
      );
    });
  });
}
