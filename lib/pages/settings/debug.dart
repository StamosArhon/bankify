import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:provider/provider.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/settings.dart';

Future<void> sendDebugLogs(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder:
        (BuildContext context) => AlertDialog(
          icon: const Icon(Icons.mail),
          title: Text(S.of(context).settingsDialogDebugSendButton),
          clipBehavior: Clip.hardEdge,
          actions: <Widget>[
            TextButton(
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: Text(S.of(context).settingsDialogDebugMailCreate),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
          content: Text(S.of(context).settingsDialogDebugMailDisclaimer),
        ),
  );
  if (!(ok ?? false) || !context.mounted) {
    return;
  }

  final PackageInfo appInfo = await PackageInfo.fromPlatform();
  final Directory tmpPath = await getTemporaryDirectory();
  final String logPath = "${tmpPath.path}/debuglog.txt";
  final bool logExists = await File(logPath).exists();
  await FlutterEmailSender.send(
    Email(
      body:
          "Debug logs generated from ${appInfo.appName}, ${appInfo.version}+${appInfo.buildNumber}.\n\nBankify redacts obvious URLs, hosts, local file paths, and token patterns before storing this file, but you should still review the attachment for any personal finance details before sharing it. Preferred reporting channel: https://github.com/StamosArhon/bankify/issues/new/choose",
      subject: "Bankify Debug Logs",
      recipients: const <String>[],
      attachmentPaths: logExists ? <String>[logPath] : const <String>[],
      isHTML: false,
    ),
  );
}

class DebugLogsPanel extends StatelessWidget {
  const DebugLogsPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets contentPadding =
        compact
            ? const EdgeInsets.fromLTRB(24, 12, 24, 0)
            : const EdgeInsets.all(24);

    return ListView(
      shrinkWrap: compact,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Padding(
          padding: contentPadding,
          child: Text(S.of(context).settingsDialogDebugInfo),
        ),
        SwitchListTile(
          value: context.select((SettingsProvider s) => s.debug),
          onChanged:
              (bool value) => context.read<SettingsProvider>().debug = value,
          title: Text(S.of(context).settingsDialogDebugTitle),
          secondary: const Icon(Icons.bug_report),
        ),
        ListTile(
          enabled: context.select((SettingsProvider s) => s.debug),
          isThreeLine: false,
          leading: const Icon(Icons.send),
          title: Text(S.of(context).settingsDialogDebugSendButton),
          subtitle: const Text(
            "Exports the locally stored redacted log so you can review it before sharing.",
          ),
          onTap: () => sendDebugLogs(context),
        ),
      ],
    );
  }
}

class DebugLogsPage extends StatelessWidget {
  const DebugLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).settingsDialogDebugTitle)),
      body: const DebugLogsPanel(),
    );
  }
}

class DebugDialog extends StatelessWidget {
  const DebugDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(S.of(context).settingsDialogDebugTitle),
      children: <Widget>[
        const SizedBox(width: 420, child: DebugLogsPanel(compact: true)),
      ],
    );
  }
}
