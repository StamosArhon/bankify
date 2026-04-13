import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bankify/animations.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/pages/splash.dart';
import 'package:bankify/widgets/erroricon.dart';
import 'package:bankify/widgets/logo.dart';

final Logger log = Logger("Pages.Login");

class UriScheme {
  static const String https = "https://";
  static const String http = "http://";

  static String normalize(String uri) {
    final String trimmed = uri.trim();
    if (trimmed.isEmpty || trimmed.contains("://")) {
      return trimmed;
    }
    return "$https$trimmed";
  }

  static bool valid(String uri) {
    final Uri? parsed = Uri.tryParse(normalize(uri));
    return parsed != null && isSupportedFireflyUri(parsed);
  }

  static bool isHttp(String uri) {
    final Uri? parsed = Uri.tryParse(uri.trim());
    return parsed?.scheme == "http";
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Logger log = Logger("Pages.Login.Page");

  final TextEditingController _hostTextController = TextEditingController();
  final TextEditingController _keyTextController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscureApiKey = true;
  String? _hostError;
  ErrorIcon _hostErrorIcon = const ErrorIcon(false);
  String? _keyError;
  ErrorIcon _keyErrorIcon = const ErrorIcon(false);
  //bool _formSubmitted = false;

  final FocusNode _hostFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _hostTextController.text = UriScheme.https;
  }

  @override
  void dispose() {
    _hostTextController.dispose();
    _keyTextController.dispose();
    _hostFocusNode.dispose();

    super.dispose();
  }

  bool _hostValid(String value) {
    return UriScheme.valid(value);
  }

  String get _hostHelperText =>
      allowsLocalDevelopmentHttp
          ? "HTTPS is recommended. Debug builds also allow explicit http:// URLs for localhost and private LAN hosts."
          : "HTTPS is required.";

  String? _hostValidationError(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return S.of(context).errorFieldRequired;
    }

    final Uri? parsed = Uri.tryParse(UriScheme.normalize(trimmed));
    if (parsed == null || parsed.host.isEmpty) {
      return S.of(context).errorInvalidURL;
    }
    if (parsed.scheme == "http") {
      if (allowsLocalDevelopmentHttpUri(parsed)) {
        return null;
      }
      return allowsLocalDevelopmentHttp
          ? "Only local HTTP hosts are allowed in debug builds."
          : "Only HTTPS URLs are allowed.";
    }
    return _hostValid(trimmed) ? null : S.of(context).errorInvalidURL;
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Column(
                children: <Widget>[
                  const SizedBox(height: 20),
                  const AppLogo(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                    child: Text(
                      S.of(context).loginWelcome,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      elevation: 0,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          S.of(context).loginAbout,
                          style: const TextStyle(height: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedHeight(
                    child: TextFormField(
                      controller: _hostTextController,
                      //readOnly: _formSubmitted,
                      focusNode: _hostFocusNode,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: S.of(context).loginFormLabelHost,
                        hintText: "https://firefly.example.com",
                        helperText: _hostHelperText,
                        suffixIcon: _hostErrorIcon,
                        errorText: _hostError,
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.url,
                      onChanged: (String value) {
                        final String? errorText =
                            value.isEmpty ? null : _hostValidationError(value);
                        final bool error = errorText != null;
                        if (error != _hostErrorIcon.isError ||
                            _hostError != errorText) {
                          setState(() {
                            _hostErrorIcon = ErrorIcon(error);
                            _hostError = errorText;
                          });
                        }
                      },
                      autovalidateMode: AutovalidateMode.disabled,
                      validator: (String? value) {
                        final String? error = _hostValidationError(value ?? "");
                        if (_hostError != error ||
                            _hostErrorIcon.isError != (error != null)) {
                          setState(() {
                            _hostErrorIcon = ErrorIcon(error != null);
                            _hostError = error;
                          });
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedHeight(
                    child: TextFormField(
                      controller: _keyTextController,
                      //readOnly: _formSubmitted,
                      obscureText: _obscureApiKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        filled: true,
                        labelText: S.of(context).loginFormLabelAPIKey,
                        hintText: "Paste your Firefly personal access token",
                        suffixIcon: SizedBox(
                          width: 96,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _keyErrorIcon,
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureApiKey = !_obscureApiKey;
                                  });
                                },
                                icon: Icon(
                                  _obscureApiKey
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ],
                          ),
                        ),
                        errorText: _keyError,
                      ),
                      onChanged: (String value) {
                        if (_keyErrorIcon.isError) {
                          setState(() {
                            _keyErrorIcon = const ErrorIcon(false);
                            _keyError = null;
                          });
                        }
                      },
                      autovalidateMode: AutovalidateMode.disabled,
                      validator: (String? value) {
                        final String? error =
                            value == null || value.isEmpty
                                ? S.of(context).errorFieldRequired
                                : null;
                        if (_keyError != error ||
                            _keyErrorIcon.isError != (error != null)) {
                          setState(() {
                            _keyErrorIcon = ErrorIcon(error != null);
                            _keyError = error;
                          });
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 12,
                    overflowSpacing: 12,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: () async {
                          final Uri uri = Uri.parse(
                            "https://docs.firefly-iii.org/how-to/firefly-iii/features/api/#personal-access-tokens",
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            throw Exception("Could not open URL");
                          }
                        },
                        child: Text(S.of(context).formButtonHelp),
                      ),
                      FilledButton(
                        onPressed: /*_formSubmitted
                            ? null
                            : */ () {
                          final String normalizedHost = UriScheme.normalize(
                            _hostTextController.text,
                          );
                          if (normalizedHost != _hostTextController.text) {
                            _hostTextController.value = TextEditingValue(
                              text: normalizedHost,
                              selection: TextSelection.collapsed(
                                offset: normalizedHost.length,
                              ),
                            );
                          }
                          _formKey.currentState!.validate();
                          if ((_keyError != null && _keyError!.isNotEmpty) ||
                              (_hostError != null && _hostError!.isNotEmpty)) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute<Widget>(
                              builder:
                                  (BuildContext context) => SplashPage(
                                    host: normalizedHost,
                                    apiKey: _keyTextController.text,
                                  ),
                            ),
                          );
                          /*setState(() {
                                  _formSubmitted = true;
                                });*/
                        },
                        child: Text(S.of(context).formButtonLogin),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
