import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:bankify/app_lock_policy.dart';
import 'package:bankify/app_profile.dart';
import 'package:bankify/app_session_state.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/notificationlistener.dart';
import 'package:bankify/pages/login.dart';
import 'package:bankify/pages/navigation.dart';
import 'package:bankify/pages/splash.dart';
import 'package:bankify/pages/transaction.dart';
import 'package:bankify/settings.dart';
import 'package:bankify/widgets/logo.dart';

final Logger log = Logger("App");

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: "Main Navigator",
);

class BankifyApp extends StatefulWidget {
  const BankifyApp({super.key});

  @override
  State<BankifyApp> createState() => _BankifyAppState();
}

class _BankifyAppState extends State<BankifyApp> {
  AppSessionState _session = const AppSessionState();
  bool _settingsLoadRequested = false;
  bool _startupTaskRunning = false;
  StreamSubscription<List<SharedFile>>? _sharingIntentSubscription;

  void _updateSession(AppSessionState next) {
    if (!mounted) {
      _session = next;
      return;
    }
    setState(() {
      _session = next;
    });
  }

  void _recordNotificationLaunch(NotificationTransaction notification) {
    _updateSession(
      _session.copyWith(
        launchRequest: _session.launchRequest.copyWith(
          notification: notification,
          clearNotification: false,
        ),
      ),
    );
  }

  void _recordQuickActionLaunch(String shortcutType) {
    _updateSession(
      _session.copyWith(
        launchRequest: _session.launchRequest.copyWith(
          quickActionType: shortcutType,
          clearQuickActionType: false,
        ),
      ),
    );
  }

  void _recordSharedFilesLaunch(List<SharedFile> files) {
    _updateSession(
      _session.copyWith(
        launchRequest: _session.launchRequest.copyWith(
          sharedFiles: files,
          clearSharedFiles: false,
        ),
      ),
    );
  }

  void _clearLaunchRequest() {
    if (_session.launchRequest.isEmpty) {
      return;
    }
    _updateSession(_session.copyWith(launchRequest: AppLaunchRequest.empty));
  }

  bool _canOpenTransactionComposerImmediately() {
    final BuildContext? navigationContext = navigatorKey.currentContext;
    if (_session.startupInProgress || navigationContext == null) {
      return false;
    }

    final FireflyService firefly = navigationContext.read<FireflyService>();
    return _session.resolveHome(
          signedIn: firefly.signedIn,
          hasStorageSignInException: firefly.storageSignInException != null,
        ) ==
        AppHomeDestination.navigation;
  }

  void _handleIncomingSharedFiles(List<SharedFile> files) {
    if (files.isEmpty) {
      return;
    }

    log.info('Received ${files.length} shared files');
    if (_canOpenTransactionComposerImmediately()) {
      log.finest(() => 'Opening composer immediately for shared files');
      unawaited(_pushTransactionComposer(files: files));
    } else {
      log.finest(() => 'Queueing shared files for startup handoff');
      _recordSharedFilesLaunch(files);
    }
    FlutterSharingIntent.instance.reset();
  }

  Future<void> _pushTransactionComposer({
    NotificationTransaction? notification,
    List<SharedFile>? files,
  }) async {
    final NavigatorState? navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    await navigator.push(
      MaterialPageRoute<Widget>(
        builder:
            (BuildContext context) =>
                TransactionPage(notification: notification, files: files),
      ),
    );
  }

  Future<void> _maybeAdvanceStartup(BuildContext context) async {
    if (_startupTaskRunning || !_session.startupInProgress) {
      return;
    }
    if (!context.read<SettingsProvider>().loaded) {
      return;
    }

    if (_session.startupPhase == AppStartupPhase.waitingForSettings) {
      if (_session.lockEnabled && !_session.unlockSatisfied) {
        _startupTaskRunning = true;
        _updateSession(
          _session.copyWith(startupPhase: AppStartupPhase.awaitingUnlock),
        );
        final bool authed = await auth();
        _startupTaskRunning = false;
        if (!mounted) {
          return;
        }
        if (!authed) {
          log.shout(() => "startup authentication failed");
          await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          return;
        }
        _updateSession(
          _session.copyWith(
            startupPhase: AppStartupPhase.waitingForSettings,
            unlockSatisfied: true,
          ),
        );
      } else {
        _startupTaskRunning = true;
        _updateSession(
          _session.copyWith(startupPhase: AppStartupPhase.signingInFromStorage),
        );
        await context.read<FireflyService>().signInFromStorage();
        _startupTaskRunning = false;
        if (!mounted) {
          return;
        }
        _updateSession(
          _session.copyWith(
            startupPhase: AppStartupPhase.ready,
            unlockSatisfied: true,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Notifications
    FlutterLocalNotificationsPlugin().initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      ),
      onDidReceiveNotificationResponse: nlNotificationTap,
    );

    FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails().then((
      NotificationAppLaunchDetails? details,
    ) async {
      log.config("checking NotificationAppLaunchDetails");
      if ((details?.didNotificationLaunchApp ?? false) &&
          (details?.notificationResponse?.payload?.isNotEmpty ?? false)) {
        log.info("Was launched from notification!");
        final NotificationTransaction? notificationPayload =
            await NotificationPayloadStore().consume(
              details!.notificationResponse!.payload!,
            );
        if (notificationPayload == null) {
          return;
        }
        _recordNotificationLaunch(notificationPayload);
      }
    });

    // Quick Actions
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      log.info("Was launched from QuickAction $shortcutType");
      final bool canOpenImmediately =
          !_session.startupInProgress &&
          navigatorKey.currentState != null &&
          (navigatorKey.currentContext?.read<FireflyService>().signedIn ??
              false);
      if (canOpenImmediately) {
        log.finest(() => "App already started, pushing route");
        unawaited(_pushTransactionComposer());
        return;
      }
      _recordQuickActionLaunch(shortcutType);
    });
    quickActions.clearShortcutItems();

    // App Lifecycle State
    AppLifecycleListener(
      onResume: () {
        if (_session.shouldRequireUnlockOnResume) {
          log.finest(
            () => "App resuming, last opened: ${_session.lastPausedAt}",
          );
          _updateSession(_session.copyWith(clearLastPausedAt: true));

          final bool canPush = navigatorKey.currentState != null;
          if (canPush) {
            navigatorKey.currentState?.push(
              MaterialPageRoute<Widget>(
                builder: (BuildContext context) => const AppLogo(),
              ),
            );
          }

          auth().then((bool authed) {
            log.finest(() => "done authing, $authed");
            if (authed) {
              log.finest(() => "authentication succeeded");
              if (canPush) {
                navigatorKey.currentState?.pop();
              }
            } else {
              log.shout(() => "authentication failed");
              _updateSession(
                _session.copyWith(lastPausedAt: forceExpiredAppLockTimestamp()),
              );
              // close app
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              if (canPush) {
                navigatorKey.currentState?.pop();
              }
            }
          });
        }
      },
      onPause: () {
        if (_session.lockEnabled) {
          _updateSession(_session.copyWith(lastPausedAt: DateTime.now()));
          log.finest(() => "App pausing now");
        }
      },
    );

    _sharingIntentSubscription = FlutterSharingIntent.instance
        .getMediaStream()
        .listen(
          _handleIncomingSharedFiles,
          onError: (Object err, StackTrace stackTrace) {
            log.warning('getMediaStream error', err, stackTrace);
          },
        );

    // For sharing images coming from outside the app while the app is closed
    FlutterSharingIntent.instance.getInitialSharing().then((
      List<SharedFile> value,
    ) {
      log.config('checking initial file sharing launch');
      log.finest(() => 'shared file count: ${value.length}');
      _handleIncomingSharedFiles(value);
    });
  }

  @override
  void dispose() {
    _sharingIntentSubscription?.cancel();
    super.dispose();
  }

  Future<bool> auth() {
    final LocalAuthentication auth = LocalAuthentication();
    return auth.authenticate(
      localizedReason: "Bankify",
      persistAcrossBackgrounding: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    log.fine(() => "BankifyApp() building");

    return DynamicColorBuilder(
      builder: (
        ColorScheme? cSchemeDynamicLight,
        ColorScheme? cSchemeDynamicDark,
      ) {
        final ColorScheme cSchemeLight = ColorScheme.fromSeed(
          seedColor: Colors.blue,
        );
        final ColorScheme cSchemeDark = ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ).copyWith(
          surfaceContainerHighest: Colors.blueGrey.shade900,
          onSurfaceVariant: Colors.white,
        );

        log.finest(
          () =>
              "has dynamic color? light: ${cSchemeDynamicLight != null}, dark: ${cSchemeDynamicDark != null}",
        );

        return MultiProvider(
          providers: <SingleChildWidget>[
            ChangeNotifierProvider<FireflyService>(
              create: (_) => FireflyService(),
            ),
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(),
            ),
          ],
          builder: (BuildContext context, _) {
            final SettingsProvider settings = context.read<SettingsProvider>();
            final bool settingsLoaded = context.select(
              (SettingsProvider s) => s.loaded,
            );
            final bool signedIn = context.select(
              (FireflyService f) => f.signedIn,
            );
            final AppProfile? currentProfile = context.select(
              (FireflyService f) => f.currentProfile,
            );
            final bool hasStorageSignInException = context.select(
              (FireflyService f) => f.storageSignInException != null,
            );

            log.finest(() => "startupPhase = ${_session.startupPhase}");
            if (!_settingsLoadRequested && !settingsLoaded) {
              _settingsLoadRequested = true;
              log.finer(() => "Load Step 1: Loading Settings");
              settings.loadSettings();
            }

            final AppSessionState syncedSession = _session.copyWith(
              lockEnabled: settings.lock,
              lockTimeout: settings.lockTimeout,
              unlockSatisfied: settings.lock ? _session.unlockSatisfied : true,
              profile: currentProfile,
              clearProfile: currentProfile == null,
            );
            if (syncedSession.lockEnabled != _session.lockEnabled ||
                syncedSession.lockTimeout != _session.lockTimeout ||
                syncedSession.unlockSatisfied != _session.unlockSatisfied ||
                syncedSession.profile != _session.profile) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                _updateSession(syncedSession);
              });
            }

            if (settingsLoaded && _session.startupInProgress) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                unawaited(_maybeAdvanceStartup(context));
              });
            }

            if (signedIn) {
              context.read<FireflyService>().tzHandler.setUseServerTime(
                settings.useServerTime,
              );
            }
            log.config("signedIn: $signedIn");

            final AppHomeDestination homeDestination = _session.resolveHome(
              signedIn: signedIn,
              hasStorageSignInException: hasStorageSignInException,
            );

            return MaterialApp(
              title: 'Bankify',
              theme: ThemeData(
                brightness: Brightness.light,
                colorScheme:
                    context.select((SettingsProvider s) => s.dynamicColors)
                        ? cSchemeDynamicLight?.harmonized() ?? cSchemeLight
                        : cSchemeLight,
                useMaterial3: true,
                // See https://github.com/flutter/flutter/issues/131042#issuecomment-1690737834
                appBarTheme: const AppBarTheme(shape: RoundedRectangleBorder()),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: <TargetPlatform, PageTransitionsBuilder>{
                    TargetPlatform.android:
                        PredictiveBackPageTransitionsBuilder(),
                  },
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                colorScheme:
                    context.select((SettingsProvider s) => s.dynamicColors)
                        ? cSchemeDynamicDark?.harmonized() ?? cSchemeDark
                        : cSchemeDark,
                useMaterial3: true,
              ),
              themeMode: context.select((SettingsProvider s) => s.theme),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              locale: context.select((SettingsProvider s) => s.locale),
              navigatorKey: navigatorKey,
              home: switch (homeDestination) {
                AppHomeDestination.splash => const SplashPage(),
                AppHomeDestination.login => const LoginPage(),
                AppHomeDestination.navigation => NavPage(
                  initialLaunchRequest:
                      _session.launchRequest.isEmpty
                          ? null
                          : _session.launchRequest,
                  onInitialLaunchHandled: _clearLaunchRequest,
                ),
              },
            );
          },
        );
      },
    );
  }
}
