import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/notificationlistener.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'bankify_notification_payload_store_test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('stores and consumes notification drafts by opaque id', () async {
    final NotificationPayloadStore store = NotificationPayloadStore(
      baseDirectory: tempDir,
    );
    final NotificationTransaction transaction = NotificationTransaction(
      'com.example.bank',
      'Coffee Shop',
      'Paid EUR 12.34 at Coffee Shop',
      DateTime.utc(2026, 4, 13, 12, 30),
    );

    final String payloadId = await store.store(transaction);

    expect(payloadId, startsWith('notification-'));
    expect(payloadId, isNot(contains('Coffee Shop')));
    expect(payloadId, isNot(contains('12.34')));

    final NotificationTransaction? consumed = await store.consume(payloadId);
    expect(consumed?.appName, transaction.appName);
    expect(consumed?.title, transaction.title);
    expect(consumed?.body, transaction.body);
    expect(consumed?.date, transaction.date);

    expect(await store.consume(payloadId), isNull);
  });

  test('uses private notification visibility for notification listener flows', () {
    expect(
      transactionReviewNotificationDetails.visibility,
      NotificationVisibility.private,
    );
    expect(
      createdTransactionNotificationDetails.visibility,
      NotificationVisibility.private,
    );
  });
}
