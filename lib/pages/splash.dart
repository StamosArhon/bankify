import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:bankify/animations.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/widgets/logo.dart';

final Logger log = Logger("Pages.Splash");

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.host, this.apiKey});

  final String? host;
  final String? apiKey;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final Logger log = Logger("Pages.Splash.Page");

  Object? _loginError;

  String get _progressLabel =>
      widget.host == null || widget.apiKey == null
          ? "Checking saved connection…"
          : "Signing in…";

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

  IconData _diagnosisIcon(ConnectionFailureDetails diagnosis) {
    switch (diagnosis.kind) {
      case ConnectionFailureKind.certificateApprovalRequired:
      case ConnectionFailureKind.untrustedCertificate:
        return Icons.verified_user_outlined;
      case ConnectionFailureKind.invalidHttpsEndpoint:
        return Icons.http_outlined;
      case ConnectionFailureKind.insecureTransport:
        return Icons.gpp_bad_outlined;
      case ConnectionFailureKind.invalidHost:
      case ConnectionFailureKind.noInstance:
        return Icons.link_off_outlined;
      case ConnectionFailureKind.invalidApiKey:
        return Icons.key_off_outlined;
      case ConnectionFailureKind.versionTooLow:
      case ConnectionFailureKind.invalidVersion:
        return Icons.system_update_outlined;
      case ConnectionFailureKind.unexpectedStatusCode:
        return Icons.warning_amber_outlined;
      case ConnectionFailureKind.networkUnavailable:
        return Icons.wifi_off_outlined;
      case ConnectionFailureKind.unknown:
        return Icons.error_outline;
    }
  }

  String _diagnosisTitle(ConnectionFailureDetails diagnosis) {
    switch (diagnosis.kind) {
      case ConnectionFailureKind.certificateApprovalRequired:
        return diagnosis.replacingExistingTrust
            ? "Certificate changed"
            : "Certificate verification required";
      case ConnectionFailureKind.untrustedCertificate:
        return "Untrusted HTTPS certificate";
      case ConnectionFailureKind.invalidHttpsEndpoint:
        return "HTTPS is not available on this port";
      case ConnectionFailureKind.insecureTransport:
        return "Unsupported connection type";
      case ConnectionFailureKind.invalidHost:
        return "Invalid Firefly URL";
      case ConnectionFailureKind.invalidApiKey:
        return "Personal access token required";
      case ConnectionFailureKind.versionTooLow:
        return "Firefly version too old";
      case ConnectionFailureKind.invalidVersion:
        return "Could not verify Firefly version";
      case ConnectionFailureKind.unexpectedStatusCode:
        return "Unexpected server response";
      case ConnectionFailureKind.noInstance:
        return "Firefly III was not detected";
      case ConnectionFailureKind.networkUnavailable:
        return "Could not reach the server";
      case ConnectionFailureKind.unknown:
        return "Could not connect";
    }
  }

  String _diagnosisSummary(ConnectionFailureDetails diagnosis) {
    switch (diagnosis.kind) {
      case ConnectionFailureKind.certificateApprovalRequired:
        return diagnosis.replacingExistingTrust
            ? "Bankify saw a different HTTPS certificate for this host than the one you previously trusted."
            : "This server uses a custom HTTPS certificate. Verify its fingerprint before trusting it.";
      case ConnectionFailureKind.untrustedCertificate:
        return "Bankify could not build a trusted HTTPS connection. Use a system-trusted certificate or retry and review the presented fingerprint.";
      case ConnectionFailureKind.invalidHttpsEndpoint:
        return "This host answered in a way that looks like plain HTTP instead of HTTPS. For local development, use an explicit http:// URL only on localhost or private LAN hosts in debug builds.";
      case ConnectionFailureKind.insecureTransport:
        return "Bankify only accepts HTTPS in normal use. Debug builds can use explicit local http:// URLs for localhost or private LAN hosts.";
      case ConnectionFailureKind.invalidHost:
        return "Enter the full Firefly III base URL, for example https://firefly.example.com.";
      case ConnectionFailureKind.invalidApiKey:
        return "Generate a Personal Access Token in Firefly III and paste it into the login form.";
      case ConnectionFailureKind.versionTooLow:
        return "This Firefly III server is older than the minimum Bankify supports.";
      case ConnectionFailureKind.invalidVersion:
        return "Bankify could not understand the API version returned by this server.";
      case ConnectionFailureKind.unexpectedStatusCode:
        return "The server responded, but not with the API response Bankify expected.";
      case ConnectionFailureKind.noInstance:
        return "The URL responded, but it does not look like a Firefly III API instance.";
      case ConnectionFailureKind.networkUnavailable:
        return "Check that the device can reach your server, then retry.";
      case ConnectionFailureKind.unknown:
        return "Bankify hit an unexpected connection problem.";
    }
  }

  List<String> _diagnosisNextSteps(ConnectionFailureDetails diagnosis) {
    switch (diagnosis.kind) {
      case ConnectionFailureKind.certificateApprovalRequired:
        return <String>[
          "Verify the SHA-256 fingerprint against your server or reverse proxy.",
          diagnosis.replacingExistingTrust
              ? "Only trust the new certificate if you expected the rotation."
              : "If it matches, continue with Trust certificate.",
        ];
      case ConnectionFailureKind.untrustedCertificate:
        return <String>[
          "Use a certificate signed by an Android system-trusted CA, or retry so Bankify can show the presented fingerprint.",
          "If you self-host, double-check the certificate chain and hostname mapping on your reverse proxy.",
        ];
      case ConnectionFailureKind.invalidHttpsEndpoint:
        return <String>[
          "If your server is HTTP-only for local development, enter the host with an explicit http:// prefix.",
          "If you expected HTTPS, check your reverse proxy, TLS termination, and port mapping.",
        ];
      case ConnectionFailureKind.insecureTransport:
        return <String>[
          "Switch the host to HTTPS, or use a debug-only local http:// URL on localhost or a private LAN IP.",
        ];
      case ConnectionFailureKind.invalidHost:
        return <String>[
          "Include the full base URL and scheme.",
          "Example: https://firefly.example.com or http://192.168.1.6:8084 in a debug build.",
        ];
      case ConnectionFailureKind.invalidApiKey:
        return <String>[
          "Create a Personal Access Token in Firefly III: Profile > OAuth > Personal Access Tokens.",
          "Paste the token exactly as generated.",
        ];
      case ConnectionFailureKind.versionTooLow:
        return <String>[
          "Upgrade Firefly III before connecting with this Bankify build.",
          if (diagnosis.requiredVersion != null)
            "Minimum supported API version: ${diagnosis.requiredVersion}",
        ];
      case ConnectionFailureKind.invalidVersion:
        return <String>[
          "Retry once to rule out a temporary proxy or caching issue.",
          "If the problem persists, check the Firefly III and reverse-proxy versions.",
        ];
      case ConnectionFailureKind.unexpectedStatusCode:
        return <String>[
          if (diagnosis.statusCode == 401 || diagnosis.statusCode == 403)
            "Check that the token is valid and still has access."
          else
            "Check the Firefly III URL, reverse proxy, and API availability.",
          if (diagnosis.statusCode != null)
            "Observed HTTP status: ${diagnosis.statusCode}.",
        ];
      case ConnectionFailureKind.noInstance:
        return <String>[
          "Double-check that this is the Firefly III base URL, not a different service or landing page.",
        ];
      case ConnectionFailureKind.networkUnavailable:
        return <String>[
          "Make sure the phone or emulator can reach the same network as your Firefly server.",
          "Verify the host, port, firewall rules, and reverse proxy.",
        ];
      case ConnectionFailureKind.unknown:
        return <String>[
          "Retry once, then review the technical details below.",
          "If the issue persists, export debug logs only after reviewing them for personal finance details.",
        ];
    }
  }

  String _technicalDetails(ConnectionFailureDetails diagnosis, String? host) {
    final List<String> details = <String>[];
    final String? effectiveHost = diagnosis.host ?? host;
    if (effectiveHost != null && effectiveHost.isNotEmpty) {
      details.add("Host: $effectiveHost");
    }
    if (diagnosis.requiredVersion != null) {
      details.add(
        "Minimum supported API version: ${diagnosis.requiredVersion}",
      );
    }
    if (diagnosis.statusCode != null) {
      details.add("HTTP status: ${diagnosis.statusCode}");
    }
    if (diagnosis.certificate != null) {
      details.add(_certificateDetails(diagnosis.certificate!));
    }
    if (diagnosis.rawError != null &&
        diagnosis.kind == ConnectionFailureKind.unknown) {
      details.add(
        "Error: ${diagnosis.rawError.runtimeType}: ${diagnosis.rawError}",
      );
    }
    return details.join("\n\n");
  }

  Future<void> _trustServerCertificate(
    AuthErrorCertificateApprovalRequired error,
  ) async {
    final bool? shouldTrust = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            icon: const Icon(Icons.verified_user),
            title: Text(
              error.replacingExistingTrust
                  ? "Trust new certificate?"
                  : "Trust this certificate?",
            ),
            content: SingleChildScrollView(
              child: SelectableText(
                "${error.cause}\n\nVerify this fingerprint with your server before continuing.\n\n${_certificateDetails(error.certificate)}",
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  error.replacingExistingTrust
                      ? "Trust new certificate"
                      : "Trust certificate",
                ),
              ),
            ],
          ),
    );

    if (shouldTrust != true || !mounted) {
      return;
    }

    await context.read<FireflyService>().trustServerCertificate(
      error.certificate,
    );
    setState(() {
      _loginError = null;
    });
    await _login(widget.host, widget.apiKey);
  }

  Future<void> _login(String? host, String? apiKey) async {
    log.fine(() => "SplashPage->_login()");

    bool success = false;

    try {
      if (host == null || apiKey == null) {
        log.finer(() => "SplashPage->_login() from storage");
        success = await context.read<FireflyService>().signInFromStorage();
      } else {
        log.finer(
          () =>
              "SplashPage->_login() with credentials: $host, apiKey ${apiKey.isEmpty ? "unset" : "set"}",
        );
        success = await context.read<FireflyService>().signIn(host, apiKey);
      }
    } catch (e, stackTrace) {
      log.warning(
        "_login got exception, assigning to _loginError",
        e,
        stackTrace,
      );
      setState(() {
        _loginError = e;
      });
    }

    log.fine(() => "_login() returning $success");

    return;
  }

  @override
  void initState() {
    super.initState();

    if (widget.host != null && widget.apiKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        log.finest(() => "initState() scheduling login");
        _login(widget.host, widget.apiKey);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build(loginError: $_loginError)");

    if (context.read<FireflyService>().signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    Widget page;

    _loginError ??= context.select(
      (FireflyService f) => f.storageSignInException,
    );

    if (_loginError == null) {
      log.finer(() => "_loginError null --> show spinner");
      page = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _progressLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      );
      const QuickActions().setShortcutItems(<ShortcutItem>[
        ShortcutItem(
          type: "action_transaction_add",
          localizedTitle: S.of(context).transactionTitleAdd,
          icon: "action_icon_add",
        ),
      ]);
    } else {
      log.finer(() => "_loginError available --> show error");
      final String? host = context.read<FireflyService>().lastTriedHost;
      final ConnectionFailureDetails diagnosis = diagnoseConnectionFailure(
        _loginError,
        host: host,
      );
      final AuthErrorCertificateApprovalRequired? certificateApprovalError =
          diagnosis.canTrustPresentedCertificate
              ? _loginError as AuthErrorCertificateApprovalRequired
              : null;
      final String technicalDetails = _technicalDetails(diagnosis, host);
      final List<String> nextSteps = _diagnosisNextSteps(diagnosis);
      page = SizedBox(
        width: double.infinity,
        child: Column(
          children: <Widget>[
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _diagnosisIcon(diagnosis),
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _diagnosisTitle(diagnosis),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _diagnosisSummary(diagnosis),
                            style: TextStyle(
                              height: 1.5,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (nextSteps.isNotEmpty)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        "Try this",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...nextSteps.map(
                        (String step) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.arrow_right, size: 20),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  step,
                                  style: const TextStyle(height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (technicalDetails.isNotEmpty)
              Card(
                elevation: 0,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    title: const Text("Technical details"),
                    children: <Widget>[
                      SelectableText(
                        technicalDetails,
                        style: const TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OverflowBar(
              alignment: MainAxisAlignment.center,
              spacing: 12,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      context.read<FireflyService>().signOut();
                    }
                  },
                  child:
                      Navigator.canPop(context)
                          ? Text(
                            MaterialLocalizations.of(context).backButtonTooltip,
                          )
                          : Text(S.of(context).formButtonResetLogin),
                ),
                if (certificateApprovalError != null)
                  FilledButton(
                    onPressed:
                        () => _trustServerCertificate(certificateApprovalError),
                    child: Text(
                      certificateApprovalError.replacingExistingTrust
                          ? "Trust new certificate"
                          : "Trust certificate",
                    ),
                  ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _loginError = null;
                    });
                    _login(widget.host, widget.apiKey);
                  },
                  child: Text(S.of(context).formButtonTryAgain),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Column(
                children: <Widget>[
                  const SizedBox(height: 20),
                  const AppLogo(),
                  const SizedBox(height: 20),
                  AnimatedHeight(child: page),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
