import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/notificationlistener.dart';
import 'package:bankify/pages/settings/debug.dart';
import 'package:bankify/pages/settings/notifications.dart';
import 'package:bankify/settings.dart';

final Logger log = Logger("Pages.Settings.PrivacyCenter");

class PrivacyCenterPage extends StatelessWidget {
  const PrivacyCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy center")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Review the features that touch notifications, local files, and exported logs. Bankify keeps these controls together so you can audit the privacy-sensitive parts of the app quickly.",
                style: TextStyle(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                subtitle = l10n.settingsNLServiceCheckingError(
                  snapshot.error.toString(),
                );
              } else {
                subtitle = l10n.settingsNLServiceChecking;
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
                        child: Icon(Icons.notifications_active_outlined),
                      ),
                      onTap: () => openContainer(),
                    ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: Text(S.of(context).settingsDialogDebugTitle),
            subtitle: Text(
              context.select((SettingsProvider s) => s.debug)
                  ? "Verbose local logging is enabled."
                  : "Verbose local logging is off.",
            ),
            leading: const CircleAvatar(child: Icon(Icons.bug_report_outlined)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<Widget>(
                  builder: (BuildContext context) => const DebugLogsPage(),
                ),
              );
            },
          ),
          const Divider(),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Shared files & attachments",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const _PrivacyBullet(
                    text:
                        "Bankify only accepts local image and PDF share intents. Remote URLs and unsupported file types are rejected.",
                  ),
                  const _PrivacyBullet(
                    text:
                        "Incoming shared files are reviewed before they become transaction attachments.",
                  ),
                  const _PrivacyBullet(
                    text:
                        "Opening a downloaded attachment in another app always requires explicit confirmation.",
                  ),
                  const _PrivacyBullet(
                    text:
                        "Bankify uses app-owned temporary files for staged imports and cleans them up when they are discarded.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  const _PrivacyBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.shield_outlined, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
