import 'package:flutter/foundation.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:bankify/app_lock_policy.dart';
import 'package:bankify/app_profile.dart';
import 'package:bankify/notificationlistener.dart';

const String transactionAddQuickActionType = 'action_transaction_add';

enum AppStartupPhase {
  waitingForSettings,
  awaitingUnlock,
  signingInFromStorage,
  ready,
}

enum AppHomeDestination { splash, login, navigation }

@immutable
class AppLaunchRequest {
  const AppLaunchRequest({
    this.quickActionType,
    this.notification,
    this.sharedFiles,
  });

  static const AppLaunchRequest empty = AppLaunchRequest();

  final String? quickActionType;
  final NotificationTransaction? notification;
  final List<SharedFile>? sharedFiles;

  bool get hasSharedFiles => sharedFiles?.isNotEmpty ?? false;

  bool get opensTransactionComposer =>
      notification != null ||
      quickActionType == transactionAddQuickActionType ||
      hasSharedFiles;

  bool get isEmpty =>
      quickActionType == null && notification == null && !hasSharedFiles;

  AppLaunchRequest copyWith({
    String? quickActionType,
    bool clearQuickActionType = false,
    NotificationTransaction? notification,
    bool clearNotification = false,
    List<SharedFile>? sharedFiles,
    bool clearSharedFiles = false,
  }) {
    return AppLaunchRequest(
      quickActionType:
          clearQuickActionType ? null : quickActionType ?? this.quickActionType,
      notification:
          clearNotification ? null : notification ?? this.notification,
      sharedFiles: clearSharedFiles ? null : sharedFiles ?? this.sharedFiles,
    );
  }
}

@immutable
class AppSessionState {
  const AppSessionState({
    this.startupPhase = AppStartupPhase.waitingForSettings,
    this.unlockSatisfied = false,
    this.lockEnabled = false,
    this.lockTimeout = defaultAppLockTimeout,
    this.lastPausedAt,
    this.profile,
    this.launchRequest = AppLaunchRequest.empty,
  });

  final AppStartupPhase startupPhase;
  final bool unlockSatisfied;
  final bool lockEnabled;
  final AppLockTimeout lockTimeout;
  final DateTime? lastPausedAt;
  final AppProfile? profile;
  final AppLaunchRequest launchRequest;

  bool get startupInProgress => startupPhase != AppStartupPhase.ready;

  bool get shouldRequireUnlockOnResume =>
      lockEnabled &&
      shouldRequireAppUnlock(lastPausedAt: lastPausedAt, timeout: lockTimeout);

  AppHomeDestination resolveHome({
    required bool signedIn,
    required bool hasStorageSignInException,
  }) {
    if (startupInProgress || !unlockSatisfied || hasStorageSignInException) {
      return AppHomeDestination.splash;
    }
    return signedIn ? AppHomeDestination.navigation : AppHomeDestination.login;
  }

  AppSessionState copyWith({
    AppStartupPhase? startupPhase,
    bool? unlockSatisfied,
    bool? lockEnabled,
    AppLockTimeout? lockTimeout,
    DateTime? lastPausedAt,
    bool clearLastPausedAt = false,
    AppProfile? profile,
    bool clearProfile = false,
    AppLaunchRequest? launchRequest,
  }) {
    return AppSessionState(
      startupPhase: startupPhase ?? this.startupPhase,
      unlockSatisfied: unlockSatisfied ?? this.unlockSatisfied,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      lockTimeout: lockTimeout ?? this.lockTimeout,
      lastPausedAt:
          clearLastPausedAt ? null : lastPausedAt ?? this.lastPausedAt,
      profile: clearProfile ? null : profile ?? this.profile,
      launchRequest: launchRequest ?? this.launchRequest,
    );
  }
}
