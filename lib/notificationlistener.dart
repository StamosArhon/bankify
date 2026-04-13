import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:notifications_listener_service/notifications_listener_service.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:timezone/data/latest.dart' as tz;
import 'package:bankify/app.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/transaction.dart';
import 'package:bankify/settings.dart';

final Logger log = Logger("NotificationListener");

class NotificationTransaction {
  NotificationTransaction(this.appName, this.title, this.body, this.date);

  final String appName;
  final String title;
  final String body;
  final DateTime date;

  NotificationTransaction.fromJson(Map<String, dynamic> json)
    : appName = json['appName'],
      title = json['title'],
      body = json['body'],
      date = DateTime.parse(json['date']);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'appName': appName,
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
  };
}

class NotificationPayloadStore {
  NotificationPayloadStore({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  static const Duration _draftLifetime = Duration(days: 1);
  static const String _draftDirectoryName = 'notification_drafts';

  Future<Directory> _resolveDirectory() async {
    final Directory baseDirectory =
        _baseDirectory ?? await getTemporaryDirectory();
    final Directory draftDirectory = Directory.fromUri(
      baseDirectory.uri.resolve('$_draftDirectoryName/'),
    );
    if (!await draftDirectory.exists()) {
      await draftDirectory.create(recursive: true);
    }
    return draftDirectory;
  }

  String _newDraftId() {
    final Random random = Random.secure();
    return 'notification-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(0x7fffffff)}';
  }

  Future<File> _resolveDraftFile(String id) async {
    final Directory draftDirectory = await _resolveDirectory();
    return File.fromUri(draftDirectory.uri.resolve('$id.json'));
  }

  Future<void> _cleanupExpiredDrafts([Directory? directory]) async {
    final Directory draftDirectory = directory ?? await _resolveDirectory();
    if (!await draftDirectory.exists()) {
      return;
    }

    final DateTime cutoff = DateTime.now().subtract(_draftLifetime);
    await for (final FileSystemEntity entity in draftDirectory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      try {
        if ((await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }

  Future<String> store(NotificationTransaction transaction) async {
    final Directory draftDirectory = await _resolveDirectory();
    await _cleanupExpiredDrafts(draftDirectory);

    final String id = _newDraftId();
    final File file = File.fromUri(draftDirectory.uri.resolve('$id.json'));
    await file.writeAsString(jsonEncode(transaction.toJson()), flush: true);
    return id;
  }

  Future<NotificationTransaction?> consume(String id) async {
    if (id.isEmpty) {
      return null;
    }

    final File file = await _resolveDraftFile(id);
    if (!await file.exists()) {
      return null;
    }

    try {
      final dynamic decoded;
      try {
        decoded = jsonDecode(await file.readAsString());
      } on FormatException {
        return null;
      }
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return NotificationTransaction.fromJson(decoded);
    } finally {
      try {
        await file.delete();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }
}

class NotificationListenerStatus {
  NotificationListenerStatus(
    this.servicePermission,
    this.serviceRunning,
    this.notificationPermission,
  );

  final bool servicePermission;
  final bool serviceRunning;
  final bool notificationPermission;
}

final RegExp rFindMoney = RegExp(
  r'(?:^|[^\w])(?<preCurrency>(?:[^\r\n\t\f\v 0-9]){0,3})\s*(?<amount>\d[.,\s\d]+(?:[.,]\d+)?)\s*(?<postCurrency>(?:[^\r\n\t\f\v 0-9]){0,3})(?:$|\s|\.|,)',
);

const AndroidNotificationDetails
createdTransactionNotificationDetails = AndroidNotificationDetails(
  'extract_transaction_created',
  'Transaction from Notification Created',
  channelDescription:
      'Notification that a Transaction has been created from another Notification.',
  importance: Importance.low,
  priority: Priority.low,
  visibility: NotificationVisibility.private,
);

const AndroidNotificationDetails
transactionReviewNotificationDetails = AndroidNotificationDetails(
  'extract_transaction',
  'Create Transaction from Notification',
  channelDescription:
      'Notification asking to create a transaction from another Notification.',
  importance: Importance.low,
  priority: Priority.low,
  visibility: NotificationVisibility.private,
);

Future<NotificationListenerStatus> nlStatus() async {
  return NotificationListenerStatus(
    await NotificationServicePlugin.instance.isServicePermissionGranted(),
    await NotificationServicePlugin.instance.isServiceRunning(),
    await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!
            .areNotificationsEnabled() ??
        false,
  );
}

@pragma('vm:entry-point')
void nlCallback() {
  log.finest(() => "nlCallback()");
  NotificationServicePlugin.instance.executeNotificationListener((
    NotificationEvent? evt,
  ) async {
    if (evt == null || evt.packageName == null) {
      return;
    }
    if (evt.packageName?.startsWith("io.github.stamosarhon.bankify") ?? false) {
      return;
    }
    if (evt.state == NotificationState.remove) {
      return;
    }
    final Iterable<RegExpMatch> matches = rFindMoney.allMatches(evt.text ?? "");
    if (matches.isEmpty) {
      log.finer(() => "notification ignored: no money found");
      return;
    }

    bool validMatch = false;
    for (RegExpMatch match in matches) {
      if ((match.namedGroup("postCurrency")?.isNotEmpty ?? false) ||
          (match.namedGroup("preCurrency")?.isNotEmpty ?? false)) {
        validMatch = true;
        break;
      }
    }
    if (!validMatch) {
      log.finer(() => "notification ignored: no money with currency found");
      return;
    }

    final SettingsProvider settings = SettingsProvider();
    await settings.notificationAddKnownApp(evt.packageName!);

    if (!(await settings.notificationUsedApps()).contains(evt.packageName)) {
      log.finer(() => "notification ignored: app not enabled");
      return;
    }

    final NotificationAppSettings appSettings = await settings
        .notificationGetAppSettings(evt.packageName!);
    final NotificationPayloadStore payloadStore = NotificationPayloadStore();
    bool showNotification = true;

    if (appSettings.autoAdd) {
      tz.initializeTimeZones();
      log.finer(() => "trying to auto-add transaction from notification");
      try {
        final FireflyService ffService = FireflyService();
        if (!await ffService.signInFromStorage()) {
          throw UnauthenticatedResponse;
        }
        final FireflyIii api = ffService.api;
        final CurrencyRead localCurrency = ffService.defaultCurrency;
        late CurrencyRead? currency;
        late double amount;

        (currency, amount) = await parseNotificationText(
          api,
          evt.text!,
          localCurrency,
        );

        // Set date
        final DateTime date =
            ffService.tzHandler
                .notificationTXTime(
                  DateTime.tryParse(evt.postTime ?? "") ?? DateTime.now(),
                )
                .toLocal();
        String note = "";
        if (appSettings.autoAdd) {
          note = evt.text ?? "";
        }

        // Check currency
        if (currency?.id != localCurrency.id) {
          throw Exception("Can't auto-add TX with foreign currency");
        }

        // Check account
        if (appSettings.defaultAccountId == null) {
          throw Exception("Can't auto-add TX with no default account ID");
        }

        final TransactionStore newTx = TransactionStore(
          groupTitle: null,
          transactions: <TransactionSplitStore>[
            TransactionSplitStore(
              type: TransactionTypeProperty.withdrawal,
              date: date,
              amount: amount.toString(),
              description: evt.title!,
              // destinationId
              // destinationName
              notes: note,
              order: 0,
              sourceId: appSettings.defaultAccountId,
            ),
          ],
          applyRules: true,
          fireWebhooks: true,
          errorIfDuplicateHash: true,
        );
        final Response<TransactionSingle> resp = await api.v1TransactionsPost(
          body: newTx,
        );
        if (!resp.isSuccessful || resp.body == null) {
          try {
            final ValidationErrorResponse valError =
                ValidationErrorResponse.fromJson(
                  json.decode(resp.error.toString()),
                );
            throw Exception("nlCallBack PostTransaction: ${valError.message}");
          } catch (_) {
            throw Exception("nlCallBack PostTransaction: unknown");
          }
        }

        unawaited(
          FlutterLocalNotificationsPlugin().show(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: "Transaction created",
            body:
                "Open Bankify to review the transaction created from a watched notification.",
            notificationDetails: const NotificationDetails(
              android: createdTransactionNotificationDetails,
            ),
            payload: "",
          ),
        );

        showNotification = false;
      } catch (e, stackTrace) {
        log.severe("Error while auto-adding transaction", e, stackTrace);
        showNotification = true;
      }
    }

    if (showNotification) {
      try {
        final String payloadId = await payloadStore.store(
          NotificationTransaction(
            evt.packageName ?? "",
            evt.title ?? "",
            evt.text ?? "",
            DateTime.tryParse(evt.postTime ?? "") ?? DateTime.now(),
          ),
        );

        unawaited(
          FlutterLocalNotificationsPlugin().show(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: "Review detected transaction",
            body:
                "Open Bankify to review a detected transaction and create it manually.",
            notificationDetails: const NotificationDetails(
              android: transactionReviewNotificationDetails,
            ),
            payload: payloadId,
          ),
        );
      } catch (e, stackTrace) {
        log.severe("Error while staging notification payload", e, stackTrace);
      }
    }
  });
}

Future<void> nlInit() async {
  log.finest(() => "nlInit()");
  await NotificationServicePlugin.instance.initialize(nlCallback);
  nlCallback();
}

Future<void> nlNotificationTap(
  NotificationResponse notificationResponse,
) async {
  log.finest(() => "nlNotificationTap()");
  if (notificationResponse.payload?.isEmpty ?? true) {
    return;
  }
  final NotificationTransaction? transaction = await NotificationPayloadStore()
      .consume(notificationResponse.payload!);
  final NavigatorState? navigatorState = navigatorKey.currentState;
  if (transaction == null ||
      navigatorState == null ||
      !navigatorState.mounted) {
    return;
  }
  await showDialog(
    context: navigatorState.context,
    builder:
        (BuildContext context) => TransactionPage(notification: transaction),
  );
}

Future<(CurrencyRead?, double)> parseNotificationText(
  FireflyIii api,
  String notificationBody,
  CurrencyRead localCurrency,
) async {
  CurrencyRead? currency;
  double amount = 0;

  // Try to extract substrings that may (or may not) relate to spending amount
  final Iterable<RegExpMatch> matches = rFindMoney.allMatches(notificationBody);

  if (matches.isNotEmpty) {
    final List<CurrencyRead> currencies =
        (await api.v1CurrenciesGet()).body!.data;
    currencies.removeWhere(
      (CurrencyRead currency) => currency.attributes.enabled != true,
    );
    currencies.add(localCurrency);

    int bestMatchIndex = -1;

    matchesloop:
    for (int i = 0; i < matches.length; ++i) {
      final RegExpMatch match = matches.elementAt(i);

      final bool hasPre = match.namedGroup("preCurrency")?.isNotEmpty ?? false;
      final bool hasPost = match.namedGroup("postCurrency")!.isNotEmpty;

      if (hasPre || hasPost) {
        final String preCurrency = match.namedGroup("preCurrency")!;
        final String postCurrency = match.namedGroup("postCurrency")!;

        // If we haven't found any good match (meaning a match with some valid
        // pre or post currency) then we should regard the current one as the
        // best one so far
        if (bestMatchIndex == -1) {
          bestMatchIndex = i;
        }

        for (CurrencyRead apiCurrency in currencies) {
          if (apiCurrency.attributes.code == preCurrency ||
              apiCurrency.attributes.symbol == preCurrency ||
              apiCurrency.attributes.code == postCurrency ||
              apiCurrency.attributes.symbol == postCurrency) {
            bestMatchIndex = i;
            currency = apiCurrency;
            break matchesloop;
          }
        }
      }
    }

    if (bestMatchIndex != -1) {
      final RegExpMatch bestMatch = matches.elementAt(bestMatchIndex);

      String amountStr = (bestMatch.namedGroup("amount") ?? "").replaceAll(
        RegExp(r"\s+"),
        "",
      );

      if (amountStr.isNotEmpty) {
        // Find the first non-digit character at the end of the string
        String separator = amountStr[0];
        for (int i = amountStr.length - 1; i >= 0; i--) {
          separator = amountStr[i];
          if (!RegExp(r'\d').hasMatch(separator)) {
            break;
          }
        }

        // Strip all non-digit characters that are not decimal separators
        if (separator == "." || separator == ",") {
          amountStr = amountStr.replaceAll(RegExp('[^0-9$separator]'), '');
        }

        amount = double.tryParse(amountStr.replaceAll(",", "."))!;
      }
    }
  }

  return (currency, amount);
}
