import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';
import 'package:material_color_utilities/material_color_utilities.dart'
    show CorePalette;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bankify/app_lock_policy.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/extensions.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/notificationlistener.dart';
import 'package:bankify/pages/settings/connection.dart';
import 'package:bankify/pages/settings/debug.dart';
import 'package:bankify/pages/settings/notifications.dart';
import 'package:bankify/settings.dart';

final Logger log = Logger("Pages.Settings");

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  final Logger log = Logger("Pages.Settings.Page");

  String _lockTimeoutLabel(BuildContext context, AppLockTimeout timeout) {
    final S l10n = S.of(context);
    switch (timeout) {
      case AppLockTimeout.immediate:
        return l10n.settingsLockTimeoutImmediate;
      case AppLockTimeout.oneMinute:
        return l10n.settingsLockTimeoutOneMinute;
      case AppLockTimeout.fiveMinutes:
        return l10n.settingsLockTimeoutFiveMinutes;
      case AppLockTimeout.tenMinutes:
        return l10n.settingsLockTimeoutTenMinutes;
      case AppLockTimeout.thirtyMinutes:
        return l10n.settingsLockTimeoutThirtyMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");

    final SettingsProvider settings = context.read<SettingsProvider>();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      primary: false,
      children: <Widget>[
        ListTile(
          title: Text(S.of(context).settingsLanguage),
          subtitle: Text(S.of(context).localeName),
          leading: const CircleAvatar(child: Icon(Icons.language)),
          onTap: () {
            showDialog<Locale?>(
              context: context,
              builder: (BuildContext context) => const LanguageDialog(),
            ).then((Locale? locale) async {
              if (locale == null) {
                return;
              }
              await settings.setLocale(locale);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                const QuickActions().setShortcutItems(<ShortcutItem>[
                  ShortcutItem(
                    type: "action_transaction_add",
                    localizedTitle: S.of(context).transactionTitleAdd,
                    icon: "action_icon_add",
                  ),
                ]);
              });
            });
          },
        ),
        FutureBuilder<CorePalette?>(
          future: DynamicColorPlugin.getCorePalette(),
          builder: (
            BuildContext context,
            AsyncSnapshot<CorePalette?> snapshot,
          ) {
            String dynamicColor = "";
            bool dynamicColorAvailable = false;
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData &&
                snapshot.data != null) {
              // Dynamic color support available
              dynamicColorAvailable = true;
              if (context.select((SettingsProvider s) => s.dynamicColors)) {
                dynamicColor = " - ${S.of(context).settingsThemeDynamicColors}";
              }
            }
            return ListTile(
              title: Text(S.of(context).settingsTheme),
              subtitle: Text(
                "${S.of(context).settingsThemeValue(context.select((SettingsProvider s) => s.theme).toString().split('.').last)}$dynamicColor",
              ),
              leading: const CircleAvatar(child: Icon(Icons.format_paint)),
              onTap: () {
                showDialog<ThemeMode?>(
                  context: context,
                  builder:
                      (BuildContext context) => ThemeDialog(
                        dynamicColorAvailable: dynamicColorAvailable,
                      ),
                ).then((ThemeMode? theme) {
                  if (theme == null) {
                    return;
                  }
                  settings.setTheme(theme);
                });
              },
            );
          },
        ),
        SwitchListTile(
          title: Text(S.of(context).settingsUseServerTimezone),
          subtitle: Text(S.of(context).settingsUseServerTimezoneHelp),
          value: context.select((SettingsProvider s) => s.useServerTime),
          secondary: CircleAvatar(
            child: Icon(
              context.select((SettingsProvider s) => s.useServerTime)
                  ? Icons.schedule
                  : Icons.schedule_outlined,
            ),
          ),
          onChanged: (bool value) async {
            await context.read<FireflyService>().tzHandler.setUseServerTime(
              value,
            );
            settings.useServerTime = value;
          },
        ),
        const Divider(),
        SwitchListTile(
          title: Text(S.of(context).settingsLockscreen),
          subtitle: Text(S.of(context).settingsLockscreenHelp),
          value: context.select((SettingsProvider s) => s.lock),
          secondary: CircleAvatar(
            child: Icon(
              context.select((SettingsProvider s) => s.lock)
                  ? Icons.lock
                  : Icons.lock_outline,
            ),
          ),
          onChanged: (bool value) async {
            final S l10n = S.of(context);
            final ScaffoldMessengerState msg = ScaffoldMessenger.of(context);
            if (value == true) {
              final LocalAuthentication auth = LocalAuthentication();
              final bool canAuth =
                  await auth.isDeviceSupported() ||
                  await auth.canCheckBiometrics;
              if (!canAuth) {
                log.warning("no auth method supported");
                return;
              }
              log.finest("trying authentication");
              late bool authed;
              try {
                authed = await auth.authenticate(
                  localizedReason: l10n.settingsLockscreenInitial,
                );
              } catch (e, stackTrace) {
                log.severe("auth failed", e, stackTrace);
                msg.showSnackBar(
                  SnackBar(
                    content: Text(l10n.errorUnknown),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              if (!authed) {
                log.warning("authentication was cancelled");
                return;
              }
            }
            settings.lock = value;
          },
        ),
        if (context.select((SettingsProvider s) => s.lock))
          ListTile(
            title: Text(S.of(context).settingsLockTimeout),
            subtitle: Text(
              "${_lockTimeoutLabel(context, context.select((SettingsProvider s) => s.lockTimeout))}\n${S.of(context).settingsLockTimeoutHelp}",
            ),
            isThreeLine: true,
            leading: const CircleAvatar(child: Icon(Icons.timer_outlined)),
            onTap: () async {
              final AppLockTimeout currentTimeout =
                  context.read<SettingsProvider>().lockTimeout;
              final AppLockTimeout? selected = await showDialog<AppLockTimeout>(
                context: context,
                builder:
                    (BuildContext context) => AppLockTimeoutDialog(
                      selectedTimeout: currentTimeout,
                      labelBuilder:
                          (AppLockTimeout timeout) =>
                              _lockTimeoutLabel(context, timeout),
                    ),
              );
              if (selected == null) {
                return;
              }
              await settings.setLockTimeout(selected);
            },
          ),
        const Divider(),
        FutureBuilder<NotificationListenerStatus>(
          future: nlStatus(),
          builder: (
            BuildContext context,
            AsyncSnapshot<NotificationListenerStatus> snapshot,
          ) {
            final S l10n = S.of(context);

            late String subtitle;
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              if (!snapshot.data!.servicePermission ||
                  !snapshot.data!.notificationPermission) {
                subtitle = l10n.settingsNLPermissionNotGranted;
              } else if (!snapshot.data!.serviceRunning) {
                subtitle = l10n.settingsNLServiceStopped;
              } else {
                subtitle = l10n.settingsNLServiceRunning;
              }
            } else if (snapshot.hasError) {
              log.severe(
                "error getting nlStatus",
                snapshot.error,
                snapshot.stackTrace,
              );
              subtitle = S
                  .of(context)
                  .settingsNLServiceCheckingError(snapshot.error.toString());
            } else {
              subtitle = S.of(context).settingsNLServiceChecking;
            }
            return OpenContainer(
              openBuilder:
                  (BuildContext context, Function closedContainer) =>
                      const SettingsNotifications(),
              openColor: Theme.of(context).cardColor,
              closedColor: Theme.of(context).cardColor,
              closedElevation: 0,
              closedBuilder:
                  (BuildContext context, Function openContainer) => ListTile(
                    title: Text(S.of(context).settingsNotificationListener),
                    subtitle: Text(subtitle, maxLines: 2),
                    leading: const CircleAvatar(
                      child: Icon(Icons.notifications),
                    ),
                    onTap: () => openContainer(),
                  ),
              onClosed: (_) => setState(() {}),
            );
          },
        ),
        const Divider(),
        FutureBuilder<TrustedServerCertificate?>(
          future:
              context
                  .read<FireflyService>()
                  .readTrustedCertificateForCurrentConnection(),
          builder: (
            BuildContext context,
            AsyncSnapshot<TrustedServerCertificate?> snapshot,
          ) {
            final FireflyService firefly = context.read<FireflyService>();
            final String? host = firefly.connectedHost ?? firefly.lastTriedHost;
            final Uri? hostUri = host == null ? null : Uri.tryParse(host);
            final String subtitle;
            if (host == null || host.isEmpty) {
              subtitle =
                  "Review the saved host, API version, and certificate trust.";
            } else if (allowsLocalDevelopmentHttpUri(hostUri!)) {
              subtitle = "$host\nLocal HTTP (debug only)";
            } else if (snapshot.connectionState != ConnectionState.done) {
              subtitle = "$host\nChecking certificate trust…";
            } else if (snapshot.data != null) {
              subtitle = "$host\nCustom HTTPS certificate trusted";
            } else {
              subtitle = "$host\nSystem-trusted HTTPS";
            }
            return ListTile(
              title: const Text("Connection & certificates"),
              subtitle: Text(subtitle, maxLines: 3),
              isThreeLine: true,
              leading: const CircleAvatar(
                child: Icon(Icons.verified_user_outlined),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<Widget>(
                    builder:
                        (BuildContext context) =>
                            const ConnectionSettingsPage(),
                  ),
                );
              },
            );
          },
        ),
        const Divider(),
        ListTile(
          title: Text(S.of(context).settingsFAQ),
          subtitle: Text(S.of(context).settingsFAQHelp),
          leading: const CircleAvatar(child: Icon(Icons.question_answer)),
          onTap: () async {
            final Uri uri = Uri.parse(
              "https://github.com/StamosArhon/bankify/blob/master/FAQ.md",
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              throw Exception("Could not open URL");
            }
          },
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
            return ListTile(
              title: Text(S.of(context).settingsVersion),
              subtitle: Text(
                (snapshot.data != null)
                    ? "${snapshot.data!.appName}, ${snapshot.data!.version}+${snapshot.data!.buildNumber}"
                    : S.of(context).settingsVersionChecking,
              ),
              leading: const CircleAvatar(
                child: Icon(Icons.info_outline_rounded),
              ),
              onTap:
                  () => showDialog(
                    context: context,
                    builder: (BuildContext context) => const DebugDialog(),
                  ),
            );
          },
        ),
      ],
    );
  }
}

class AppLockTimeoutDialog extends StatelessWidget {
  const AppLockTimeoutDialog({
    super.key,
    required this.selectedTimeout,
    required this.labelBuilder,
  });

  final AppLockTimeout selectedTimeout;
  final String Function(AppLockTimeout timeout) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(S.of(context).settingsLockTimeoutDialogTitle),
      children: <Widget>[
        RadioGroup<AppLockTimeout>(
          groupValue: selectedTimeout,
          onChanged: (AppLockTimeout? value) {
            Navigator.of(context).pop(value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                AppLockTimeout.values.map((AppLockTimeout timeout) {
                  return RadioListTile<AppLockTimeout>(
                    value: timeout,
                    title: Text(labelBuilder(timeout)),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}

class LanguageDialog extends StatelessWidget {
  const LanguageDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(S.of(context).settingsDialogLanguageTitle),
      children: <Widget>[
        RadioGroup<Locale>(
          groupValue: LocaleExt.fromLanguageTag(S.of(context).localeName),
          onChanged: (Locale? locale) {
            Navigator.pop(context, locale);
          },
          child: Column(
            children: <Widget>[
              ...S.supportedLocales.map(
                (Locale locale) => RadioListTile<Locale>(
                  value: locale,
                  title: Text(locale.toLanguageTag()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ThemeDialog extends StatelessWidget {
  const ThemeDialog({super.key, required this.dynamicColorAvailable});

  final bool dynamicColorAvailable;

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.read<SettingsProvider>();
    return SimpleDialog(
      title: Text(S.of(context).settingsDialogThemeTitle),
      children: <Widget>[
        dynamicColorAvailable
            ? SwitchListTile(
              title: Text(S.of(context).settingsThemeDynamicColors),
              value: context.select((SettingsProvider s) => s.dynamicColors),
              isThreeLine: false,
              onChanged: (bool value) => settings.dynamicColors = value,
            )
            : const SizedBox.shrink(),
        RadioGroup<ThemeMode>(
          groupValue: settings.theme,
          onChanged: (ThemeMode? theme) {
            Navigator.pop(context, theme);
          },
          child: Column(
            children: <Widget>[
              ...ThemeMode.values.map(
                (ThemeMode theme) => RadioListTile<ThemeMode>(
                  value: theme,
                  title: Text(
                    S
                        .of(context)
                        .settingsThemeValue(theme.toString().split('.').last),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
