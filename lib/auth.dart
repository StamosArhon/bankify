import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart'
    show
        Chain,
        HttpMethod,
        Interceptor,
        Request,
        Response,
        StripStringExtension,
        applyHeaders;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/stock.dart';
import 'package:waterflyiii/timezonehandler.dart';

final Logger log = Logger("Auth");
final Version minApiVersion = Version(6, 3, 2);
const String secureHostScheme = "https://";

int effectiveUriPort(Uri uri) {
  if (uri.hasPort) {
    return uri.port;
  }

  switch (uri.scheme) {
    case "https":
      return 443;
    case "http":
      return 80;
    default:
      return 0;
  }
}

String tlsAuthorityForHostPort(String host, int port) {
  return "${host.toLowerCase()}:$port";
}

String tlsAuthorityForUri(Uri uri) {
  return tlsAuthorityForHostPort(uri.host, effectiveUriPort(uri));
}

String certificateSha256Fingerprint(List<int> bytes) {
  return sha256
      .convert(bytes)
      .bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, "0").toUpperCase())
      .join(":");
}

class APITZReply {
  APITZReply(this.data);
  APITZReplyData data;

  factory APITZReply.fromJson(dynamic json) {
    return APITZReply(APITZReplyData.fromJson(json['data']));
  }
}

class APITZReplyData {
  APITZReplyData(this.title, this.value, this.editable);
  String title;
  String value;
  bool editable;

  factory APITZReplyData.fromJson(dynamic json) {
    return APITZReplyData(
      json['title'] as String,
      json['value'] as String,
      json['editable'] as bool,
    );
  }
}

// :TODO: translate strings. cause returns just an identifier for the translation.
class AuthError implements Exception {
  const AuthError(this.cause);

  final String cause;
}

class AuthErrorHost extends AuthError {
  const AuthErrorHost(this.host) : super("Invalid host");

  final String host;
}

class AuthErrorApiKey extends AuthError {
  const AuthErrorApiKey() : super("Invalid API key");
}

class AuthErrorInsecureTransport extends AuthError {
  const AuthErrorInsecureTransport()
    : super("Only HTTPS Firefly III URLs are supported.");
}

class AuthErrorUntrustedCertificate extends AuthError {
  const AuthErrorUntrustedCertificate()
    : super(
        "Could not establish a trusted HTTPS connection. Use a certificate signed by a system-trusted CA.",
      );
}

class TrustedServerCertificate {
  const TrustedServerCertificate({
    required this.authority,
    required this.sha256Fingerprint,
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validTo,
  });

  final String authority;
  final String sha256Fingerprint;
  final String subject;
  final String issuer;
  final DateTime validFrom;
  final DateTime validTo;

  factory TrustedServerCertificate.fromX509Certificate(
    X509Certificate certificate,
    String host,
    int port,
  ) {
    return TrustedServerCertificate(
      authority: tlsAuthorityForHostPort(host, port),
      sha256Fingerprint: certificateSha256Fingerprint(certificate.der),
      subject: certificate.subject,
      issuer: certificate.issuer,
      validFrom: certificate.startValidity.toUtc(),
      validTo: certificate.endValidity.toUtc(),
    );
  }

  bool matchesUri(Uri uri) => authority == tlsAuthorityForUri(uri);

  bool matchesHostPort(String host, int port) {
    return authority == tlsAuthorityForHostPort(host, port);
  }

  bool acceptsCertificate(X509Certificate certificate, String host, int port) {
    if (!matchesHostPort(host, port)) {
      return false;
    }

    final DateTime now = DateTime.now().toUtc();
    final DateTime notBefore = certificate.startValidity.toUtc();
    final DateTime notAfter = certificate.endValidity.toUtc();

    return sha256Fingerprint ==
            certificateSha256Fingerprint(certificate.der) &&
        !now.isBefore(notBefore) &&
        !now.isAfter(notAfter);
  }
}

class AuthErrorCertificateApprovalRequired extends AuthError {
  const AuthErrorCertificateApprovalRequired(
    this.certificate, {
    this.replacingExistingTrust = false,
  }) : super(
         replacingExistingTrust
             ? "The trusted HTTPS certificate for this host changed. Verify the new fingerprint before trusting it again."
             : "This Firefly III server uses a custom HTTPS certificate. Verify the fingerprint before trusting it.",
       );

  final TrustedServerCertificate certificate;
  final bool replacingExistingTrust;
}

class AuthErrorVersionInvalid extends AuthError {
  const AuthErrorVersionInvalid() : super("Invalid Firefly API version");
}

class AuthErrorVersionTooLow extends AuthError {
  const AuthErrorVersionTooLow(this.requiredVersion)
    : super("Firefly API version too low");

  final Version requiredVersion;
}

class AuthErrorStatusCode extends AuthError {
  const AuthErrorStatusCode(this.code) : super("Unexpected HTTP status code");

  final int code;
}

class AuthErrorNoInstance extends AuthError {
  const AuthErrorNoInstance(this.host)
    : super("Not a valid Firefly III instance");

  final String host;
}

http.Client get httpClient =>
    createHttpClient();

http.Client createHttpClient({
  TrustedServerCertificate? trustedCertificate,
  void Function(TrustedServerCertificate certificate)? onInvalidCertificate,
}) {
  final HttpClient client = HttpClient(
    context: SecurityContext(withTrustedRoots: true),
  );
  client.badCertificateCallback = (
    X509Certificate cert,
    String host,
    int port,
  ) {
    final TrustedServerCertificate presentedCertificate =
        TrustedServerCertificate.fromX509Certificate(cert, host, port);
    onInvalidCertificate?.call(presentedCertificate);
    if (trustedCertificate == null) {
      return false;
    }
    return trustedCertificate.acceptsCertificate(cert, host, port);
  };
  return IOClient(client);
}

void disallowRedirects(http.BaseRequest request) {
  request.followRedirects = false;
  request.maxRedirects = 0;
}

Uri fireflyAttachmentDownloadUri(AuthUser user, String attachmentId) {
  return user.host.replace(
    pathSegments: <String>[
      ...user.host.pathSegments,
      "v1",
      "attachments",
      attachmentId,
      "download",
    ],
  );
}

Uri fireflyAttachmentUploadUri(AuthUser user, String attachmentId) {
  return user.host.replace(
    pathSegments: <String>[
      ...user.host.pathSegments,
      "v1",
      "attachments",
      attachmentId,
      "upload",
    ],
  );
}

class APIRequestInterceptor implements Interceptor {
  APIRequestInterceptor(this.headerFunc);

  final Function() headerFunc;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) {
    log.finest(() => "API query ${chain.request.method} ${chain.request.url}");
    if (chain.request.body != null) {
      log.finest(() => "Query Body: ${chain.request.body}");
    }
    final Request request = applyHeaders(
      chain.request,
      headerFunc(),
      override: true,
    );
    disallowRedirects(request);
    return chain.proceed(request);
  }
}

class AuthUser {
  late Uri _host;
  late String _apiKey;
  late FireflyIii _api;
  late http.Client _httpClient;

  //late FireflyIiiV2 _apiV2;

  Uri get host => _host;
  FireflyIii get api => _api;
  http.Client get httpClient => _httpClient;

  //FireflyIiiV2 get apiV2 => _apiV2;

  final Logger log = Logger("Auth.AuthUser");

  AuthUser._create(Uri host, String apiKey, http.Client client) {
    log.config("AuthUser->_create($host)");
    _apiKey = apiKey;
    _httpClient = client;

    _host = host.replace(pathSegments: <String>[...host.pathSegments, "api"]);

    _api = FireflyIii.create(
      baseUrl: _host,
      httpClient: _httpClient,
      interceptors: <Interceptor>[APIRequestInterceptor(headers)],
    );

    /*_apiV2 = FireflyIiiV2.create(
      baseUrl: _host,
      httpClient: httpClient,
      interceptors: <Interceptor>[APIRequestInterceptor(headers)],
    );*/
  }

  Map<String, String> headers() {
    return <String, String>{
      HttpHeaders.authorizationHeader: "Bearer $_apiKey",
      HttpHeaders.acceptHeader: "application/json",
    };
  }

  void dispose() {
    _httpClient.close();
  }

  static Future<AuthUser> create(
    String host,
    String apiKey, {
    TrustedServerCertificate? trustedCertificate,
  }) async {
    final Logger log = Logger("Auth.AuthUser");
    log.config("AuthUser->create($host)");

    // This call is on purpose not using the Swagger API
    TrustedServerCertificate? presentedCertificate;
    final http.Client client = createHttpClient(
      trustedCertificate: trustedCertificate,
      onInvalidCertificate: (TrustedServerCertificate certificate) {
        presentedCertificate = certificate;
      },
    );
    late Uri uri;
    bool keepClient = false;

    try {
      uri = Uri.parse(host);
    } on FormatException {
      throw AuthErrorHost(host);
    }
    if (uri.host.isEmpty) {
      throw AuthErrorHost(host);
    }
    if (uri.scheme != "https") {
      throw const AuthErrorInsecureTransport();
    }

    final Uri aboutUri = uri.replace(
      pathSegments: <String>[...uri.pathSegments, "api", "v1", "about"],
    );

    try {
      final http.Request request = http.Request(HttpMethod.Get, aboutUri);
      request.headers[HttpHeaders.authorizationHeader] = "Bearer $apiKey";
      // See #497, redirect is a bad way to check for (un)successful login.
      disallowRedirects(request);
      final http.StreamedResponse response = await client.send(request);

      // If we get an html page, it's most likely the login page, and auth failed
      if (response.headers[HttpHeaders.contentTypeHeader]?.startsWith(
            "text/html",
          ) ??
          true) {
        throw const AuthErrorApiKey();
      }
      if (response.statusCode != 200) {
        throw AuthErrorStatusCode(response.statusCode);
      }

      final String stringData = await response.stream.bytesToString();

      try {
        SystemInfo.fromJson(json.decode(stringData));
      } on FormatException {
        throw AuthErrorNoInstance(host);
      }
      keepClient = true;
    } on HandshakeException {
      if (presentedCertificate != null) {
        throw AuthErrorCertificateApprovalRequired(
          presentedCertificate!,
          replacingExistingTrust: trustedCertificate != null,
        );
      }
      throw const AuthErrorUntrustedCertificate();
    } on http.ClientException catch (e) {
      if (presentedCertificate != null) {
        throw AuthErrorCertificateApprovalRequired(
          presentedCertificate!,
          replacingExistingTrust: trustedCertificate != null,
        );
      }
      final String message = e.message.toLowerCase();
      if (message.contains("certificate") ||
          message.contains("cert") ||
          message.contains("tls") ||
          message.contains("ssl")) {
        throw const AuthErrorUntrustedCertificate();
      }
      rethrow;
    } on SocketException {
      if (presentedCertificate != null) {
        throw AuthErrorCertificateApprovalRequired(
          presentedCertificate!,
          replacingExistingTrust: trustedCertificate != null,
        );
      }
      rethrow;
    } finally {
      if (!keepClient) {
        client.close();
      }
    }

    return AuthUser._create(uri, apiKey, client);
  }
}

class FireflyService with ChangeNotifier {
  static const String storageApiHost = 'api_host';
  static const String storageApiKey = 'api_key';
  static const String storageTlsAuthority = 'api_tls_authority';
  static const String storageTlsFingerprint = 'api_tls_fingerprint';
  static const String storageTlsSubject = 'api_tls_subject';
  static const String storageTlsIssuer = 'api_tls_issuer';
  static const String storageTlsValidFrom = 'api_tls_valid_from';
  static const String storageTlsValidTo = 'api_tls_valid_to';

  AuthUser? _currentUser;
  AuthUser? get user => _currentUser;
  bool _signedIn = false;
  bool get signedIn => _signedIn;
  String? _lastTriedHost;
  String? get lastTriedHost => _lastTriedHost;
  Object? _storageSignInException;
  Object? get storageSignInException => _storageSignInException;
  Version? _apiVersion;
  Version? get apiVersion => _apiVersion;
  TrustedServerCertificate? _pendingTrustedCertificate;

  TransStock? _transStock;
  TransStock? get transStock => _transStock;

  bool get hasApi => (_currentUser?.api != null) ? true : false;
  FireflyIii get api {
    if (_currentUser?.api == null) {
      signOut();
      throw Exception("FireflyService.api: API unavailable");
    }
    return _currentUser!.api;
  }

  /*FireflyIiiV2 get apiV2 {
    if (_currentUser?.apiV2 == null) {
      signOut();
      throw Exception("FireflyService.apiV2: API unavailable");
    }
    return _currentUser!.apiV2;
  }*/

  late CurrencyRead defaultCurrency;
  late TimeZoneHandler tzHandler;

  final FlutterSecureStorage storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  final Logger log = Logger("Auth.FireflyService");

  FireflyService() {
    log.finest(() => "new FireflyService");
  }

  Future<TrustedServerCertificate?> _readStoredTrustedCertificate(
    String host,
  ) async {
    final Uri uri = Uri.parse(host);
    final String authority = tlsAuthorityForUri(uri);
    final String? storedAuthority = await storage.read(key: storageTlsAuthority);
    if (storedAuthority != authority) {
      return null;
    }

    final String? fingerprint = await storage.read(key: storageTlsFingerprint);
    final String? subject = await storage.read(key: storageTlsSubject);
    final String? issuer = await storage.read(key: storageTlsIssuer);
    final String? validFrom = await storage.read(key: storageTlsValidFrom);
    final String? validTo = await storage.read(key: storageTlsValidTo);

    if (fingerprint == null ||
        subject == null ||
        issuer == null ||
        validFrom == null ||
        validTo == null) {
      return null;
    }

    final DateTime? parsedValidFrom = DateTime.tryParse(validFrom);
    final DateTime? parsedValidTo = DateTime.tryParse(validTo);
    if (parsedValidFrom == null || parsedValidTo == null) {
      return null;
    }

    return TrustedServerCertificate(
      authority: storedAuthority!,
      sha256Fingerprint: fingerprint,
      subject: subject,
      issuer: issuer,
      validFrom: parsedValidFrom,
      validTo: parsedValidTo,
    );
  }

  Future<void> _persistTrustedCertificate(
    TrustedServerCertificate certificate,
  ) async {
    await storage.write(key: storageTlsAuthority, value: certificate.authority);
    await storage.write(
      key: storageTlsFingerprint,
      value: certificate.sha256Fingerprint,
    );
    await storage.write(key: storageTlsSubject, value: certificate.subject);
    await storage.write(key: storageTlsIssuer, value: certificate.issuer);
    await storage.write(
      key: storageTlsValidFrom,
      value: certificate.validFrom.toIso8601String(),
    );
    await storage.write(
      key: storageTlsValidTo,
      value: certificate.validTo.toIso8601String(),
    );
  }

  Future<void> _clearTrustedCertificate() async {
    await storage.delete(key: storageTlsAuthority);
    await storage.delete(key: storageTlsFingerprint);
    await storage.delete(key: storageTlsSubject);
    await storage.delete(key: storageTlsIssuer);
    await storage.delete(key: storageTlsValidFrom);
    await storage.delete(key: storageTlsValidTo);
  }

  Future<void> trustServerCertificate(
    TrustedServerCertificate certificate,
  ) async {
    _pendingTrustedCertificate = certificate;
  }

  Future<bool> signInFromStorage() async {
    _storageSignInException = null;
    final String? apiHost = await storage.read(key: storageApiHost);
    final String? apiKey = await storage.read(key: storageApiKey);

    log.config(
      "storage: $apiHost, apiKey ${apiKey?.isEmpty ?? true ? "unset" : "set"}",
    );

    if (apiHost == null || apiKey == null) {
      return false;
    }

    try {
      await signIn(apiHost, apiKey);
      return true;
    } catch (e) {
      _storageSignInException = e;
      log.finest(() => "notify FireflyService->signInFromStorage");
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    log.config("FireflyService->signOut()");
    _currentUser?.dispose();
    _currentUser = null;
    _signedIn = false;
    _storageSignInException = null;
    _pendingTrustedCertificate = null;
    await storage.deleteAll();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    log.finest(() => "notify FireflyService->signOut");
    notifyListeners();
  }

  Future<bool> signIn(String host, String apiKey) async {
    log.config("FireflyService->signIn($host)");
    host = host.strip().rightStrip('/');
    if (host.isNotEmpty && !host.contains("://")) {
      host = "$secureHostScheme$host";
    }
    apiKey = apiKey.strip();

    _lastTriedHost = host;
    final Uri trustedCertificateUri = Uri.parse(host);
    final TrustedServerCertificate? storedTrustedCertificate =
        await _readStoredTrustedCertificate(host);
    final TrustedServerCertificate? trustedCertificate =
        (_pendingTrustedCertificate?.matchesUri(trustedCertificateUri) ?? false)
            ? _pendingTrustedCertificate
            : storedTrustedCertificate;

    _currentUser = await AuthUser.create(
      host,
      apiKey,
      trustedCertificate: trustedCertificate,
    );
    if (_currentUser == null || !hasApi) return false;

    final Response<CurrencySingle> currencyInfo =
        await api.v1CurrenciesPrimaryGet();
    defaultCurrency = currencyInfo.body!.data;

    final Response<SystemInfo> about = await api.v1AboutGet();
    try {
      String apiVersionStr = about.body?.data?.apiVersion ?? "";
      if (apiVersionStr.startsWith("develop/")) {
        apiVersionStr = "9.9.9";
      }
      _apiVersion = Version.parse(apiVersionStr);
    } on FormatException {
      throw const AuthErrorVersionInvalid();
    }
    log.info(() => "Firefly API version $_apiVersion");
    if (apiVersion == null || apiVersion! < minApiVersion) {
      throw AuthErrorVersionTooLow(minApiVersion);
    }

    // Manual API query as the Swagger type doesn't resolve in Flutter :(
    final Uri tzUri = user!.host.replace(
      pathSegments: <String>[
        ...user!.host.pathSegments,
        "v1",
        "configuration",
        ConfigValueFilter.appTimezone.value!,
      ],
    );
    final http.Request request = http.Request(HttpMethod.Get, tzUri);
    request.headers.addAll(user!.headers());
    disallowRedirects(request);
    final http.StreamedResponse response = await user!.httpClient.send(request);
    final String responseBody = await response.stream.bytesToString();
    final APITZReply reply = APITZReply.fromJson(json.decode(responseBody));
    tzHandler = TimeZoneHandler(reply.data.value);

    _signedIn = true;
    _transStock = TransStock(api);
    log.finest(() => "notify FireflyService->signIn");
    notifyListeners();

    await storage.write(key: storageApiHost, value: host);
    await storage.write(key: storageApiKey, value: apiKey);
    if (trustedCertificate != null) {
      await _persistTrustedCertificate(trustedCertificate);
    } else {
      await _clearTrustedCertificate();
    }
    _pendingTrustedCertificate = null;

    return true;
  }
}

void apiThrowErrorIfEmpty(Response<dynamic> response, BuildContext? context) {
  if (response.isSuccessful && response.body != null) {
    return;
  }
  log.severe("Invalid API response", response.error);
  if (context?.mounted ?? false) {
    throw Exception(
      S.of(context!).errorAPIInvalidResponse(response.error?.toString() ?? ""),
    );
  } else {
    throw Exception("[nocontext] Invalid API response: ${response.error}");
  }
}
