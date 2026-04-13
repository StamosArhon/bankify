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
  bool _startup = true;
  bool _authed = false;
  String? _quickAction;
  NotificationTransaction? _notificationPayload;
  // Not needed right now, as sharing while the app is open does not work
  //late StreamSubscription<List<SharedFile>> _intentDataStreamSubscription;
  List<SharedFile>? _filesSharedToApp;
  bool _requiresAuth = false;
  AppLockTimeout _lockTimeout = defaultAppLockTimeout;
  DateTime? _lcLastOpen;

  @override
  void initState() {
    super.initState();

    // Notifications
    FlutterLocalNotificationsPlugin().initialize(
      const InitializationSettings(
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
        if (!mounted || notificationPayload == null) {
          return;
        }
        setState(() {
          _notificationPayload = notificationPayload;
        });
      }
    });

    // Quick Actions
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      log.info("Was launched from QuickAction $shortcutType");
      _quickAction = shortcutType;
      if (!_startup && navigatorKey.currentState != null) {
        log.finest(() => "App already started, pushing route");
        navigatorKey.currentState!.push(
          MaterialPageRoute<Widget>(
            builder: (BuildContext context) => const TransactionPage(),
          ),
        );
      }
    });
    quickActions.clearShortcutItems();

    // App Lifecycle State
    AppLifecycleListener(
      onResume: () {
        if (_requiresAuth &&
            shouldRequireAppUnlock(
              lastPausedAt: _lcLastOpen,
              timeout: _lockTimeout,
            )) {
          log.finest(() => "App resuming, last opened: $_lcLastOpen");
          _lcLastOpen = null;
          _authed = false;

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
              _authed = true;
              if (canPush) {
                navigatorKey.currentState?.pop();
              }
            } else {
              log.shout(() => "authentication failed");
              _lcLastOpen = forceExpiredAppLockTimestamp();
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
        if (_requiresAuth) {
          _lcLastOpen = DateTime.now();
          log.finest(() => "App pausing now");
        }
      },
    );

    // Share to Bankify
    // While the app is open...
    /* Sharing while app is open is currently not supported :(
       The fix from https://github.com/bhagat-techind/flutter_sharing_intent/issues/33
       does not seem to work, unfortunately.
       
    _intentDataStreamSubscription = FlutterSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedFile> value) {
      setState(() {
        list = value;
      });
      debugPrint(
          "Shared: getMediaStream ${value.map((SharedFile f) => f.value).join(",")}");
    }, onError: (Object err) {
      debugPrint("getIntentDataStream error: $err");
    });*/

    // For sharing images coming from outside the app while the app is closed
    FlutterSharingIntent.instance.getInitialSharing().then((
      List<SharedFile> value,
    ) {
      log.config("App was opened via file sharing");
      log.finest(() => "shared file count: ${value.length}");
      _filesSharedToApp = value;
      FlutterSharingIntent.instance.reset();
    });
  }

  /* Not needed right now, as sharing while the app is open does not work
  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();

    super.dispose();
  }*/

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
            late bool signedIn;
            log.finest(() => "_startup = $_startup");
            _requiresAuth = context.watch<SettingsProvider>().lock;
            _lockTimeout = context.watch<SettingsProvider>().lockTimeout;
            log.finest(() => "_requiresAuth = $_requiresAuth");
            if (_startup) {
              signedIn = false;

              if (!context.select((SettingsProvider s) => s.loaded)) {
                log.finer(() => "Load Step 1: Loading Settings");
                context.read<SettingsProvider>().loadSettings();
              } else {
                log.finer(() => "Load Step 2: Signin In");

                if (context.read<SettingsProvider>().lock && !_authed) {
                  // Authentication required
                  log.fine("awaiting authentication");
                  auth().then((bool authed) {
                    log.finest(() => "done authing, $authed");
                    if (authed) {
                      log.finest(() => "authentication succeeded");
                      setState(() {
                        _authed = true;
                      });
                    } else {
                      log.shout(() => "authentication failed");
                      // close app
                      SystemChannels.platform.invokeMethod(
                        'SystemNavigator.pop',
                      );
                    }
                  });
                } else {
                  log.finest(() => "signing in");
                  context.read<FireflyService>().signInFromStorage().then(
                    (bool _) => setState(() {
                      log.finest(() => "set _startup = false");
                      _authed = true;
                      _startup = false;
                    }),
                  );
                }
              }
            } else {
              signedIn = context.select((FireflyService f) => f.signedIn);
              if (signedIn) {
                context.read<FireflyService>().tzHandler.setUseServerTime(
                  context.read<SettingsProvider>().useServerTime,
                );
              }
              log.config("signedIn: $signedIn");
            }

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
              home:
                  ((_startup || !_authed) ||
                          context.select(
                            (FireflyService f) =>
                                f.storageSignInException != null,
                          ))
                      ? const SplashPage()
                      : signedIn
                      ? (_notificationPayload != null ||
                              _quickAction == "action_transaction_add" ||
                              (_filesSharedToApp != null &&
                                  _filesSharedToApp!.isNotEmpty))
                          ? TransactionPage(
                            notification: _notificationPayload,
                            files: _filesSharedToApp,
                            onSharedFilesConsumed:
                                (_filesSharedToApp?.isNotEmpty ?? false)
                                    ? () {
                                      if (!mounted) {
                                        return;
                                      }
                                      setState(() {
                                        _filesSharedToApp = null;
                                      });
                                    }
                                    : null,
                          )
                          : const NavPage()
                      : const LoginPage(),
            );
          },
        );
      },
    );
  }
}
