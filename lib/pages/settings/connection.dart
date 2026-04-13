import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bankify/auth.dart';

class ConnectionSettingsPage extends StatelessWidget {
  const ConnectionSettingsPage({super.key});

  String _transportLabel(Uri? uri, TrustedServerCertificate? certificate) {
    if (uri == null) {
      return "Unavailable";
    }
    if (allowsLocalDevelopmentHttpUri(uri)) {
      return "Local HTTP (debug only)";
    }
    if (certificate != null) {
      return "Custom HTTPS certificate trusted";
    }
    if (uri.scheme == "https") {
      return "System-trusted HTTPS";
    }
    return "Unknown";
  }

  String _transportHelp(Uri? uri, TrustedServerCertificate? certificate) {
    if (uri == null) {
      return "Bankify does not have a saved connection to inspect yet.";
    }
    if (allowsLocalDevelopmentHttpUri(uri)) {
      return "This connection is using local HTTP for development. Release builds still require HTTPS.";
    }
    if (certificate != null) {
      return "Bankify is pinning the certificate shown below for this host. Removing it signs you out so the next connection must be verified again.";
    }
    if (uri.scheme == "https") {
      return "Bankify is relying on Android's system-trusted certificate store for this HTTPS connection.";
    }
    return "Review the host and transport settings before reconnecting.";
  }

  String _certificateDetails(TrustedServerCertificate certificate) {
    return <String>[
      "Authority: ${certificate.authority}",
      "SHA-256: ${certificate.sha256Fingerprint}",
      "Subject: ${certificate.subject}",
      "Issuer: ${certificate.issuer}",
      "Valid from: ${certificate.validFrom.toLocal().toIso8601String()}",
      "Valid to: ${certificate.validTo.toLocal().toIso8601String()}",
    ].join("\n");
  }

  @override
  Widget build(BuildContext context) {
    final FireflyService firefly = context.read<FireflyService>();
    final String? host = firefly.connectedHost ?? firefly.lastTriedHost;
    final Uri? hostUri = host == null ? null : Uri.tryParse(host);

    return Scaffold(
      appBar: AppBar(title: const Text("Connection & certificates")),
      body: FutureBuilder<TrustedServerCertificate?>(
        future: firefly.readTrustedCertificateForCurrentConnection(),
        builder: (
          BuildContext context,
          AsyncSnapshot<TrustedServerCertificate?> snapshot,
        ) {
          final TrustedServerCertificate? certificate = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        "Current connection",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        host ?? "No saved connection yet",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "API version: ${firefly.apiVersion?.toString() ?? "Not checked yet"}",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Transport: ${_transportLabel(hostUri, certificate)}",
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _transportHelp(hostUri, certificate),
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        certificate == null
                            ? "Saved certificate trust"
                            : "Trusted certificate",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState != ConnectionState.done)
                        const LinearProgressIndicator()
                      else if (certificate == null)
                        const Text(
                          "No custom certificate is stored for this connection.",
                          style: TextStyle(height: 1.4),
                        )
                      else
                        SelectionArea(
                          child: Text(
                            _certificateDetails(certificate),
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (certificate != null) ...<Widget>[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.logout),
                            title: const Text(
                              "Forget trusted certificate and sign out?",
                            ),
                            content: const Text(
                              "For safety, Bankify will remove the saved certificate trust and sign you out. You will need to verify the certificate again on the next login.",
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).cancelButtonLabel,
                                ),
                              ),
                              FilledButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text("Forget and sign out"),
                              ),
                            ],
                          ),
                    );
                    if (confirmed != true || !context.mounted) {
                      return;
                    }
                    await context.read<FireflyService>().signOut();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(
                      context,
                    ).popUntil((Route<dynamic> route) => route.isFirst);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Forget trusted certificate and sign out"),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
