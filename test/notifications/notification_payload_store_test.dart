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

  test(
    'store cleans up stale draft json files but keeps unrelated files',
    () async {
      final NotificationPayloadStore store = NotificationPayloadStore(
        baseDirectory: tempDir,
      );
      final Directory draftDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}notification_drafts',
      );
      await draftDir.create(recursive: true);

      final File staleDraft = File(
        '${draftDir.path}${Platform.pathSeparator}stale.json',
      );
      await staleDraft.writeAsString('{"appName":"old"}');
      await staleDraft.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      final File unrelatedFile = File(
        '${draftDir.path}${Platform.pathSeparator}keep.txt',
      );
      await unrelatedFile.writeAsString('keep');
      await unrelatedFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );

      await store.store(
        NotificationTransaction(
          'com.example.bank',
          'Groceries',
          'Paid EUR 9.90',
          DateTime.utc(2026, 4, 13, 9),
        ),
      );

      expect(await staleDraft.exists(), isFalse);
      expect(await unrelatedFile.exists(), isTrue);
    },
  );

  test('consume deletes malformed drafts after returning null', () async {
    final NotificationPayloadStore store = NotificationPayloadStore(
      baseDirectory: tempDir,
    );
    final Directory draftDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}notification_drafts',
    );
    await draftDir.create(recursive: true);
    final File invalidDraft = File(
      '${draftDir.path}${Platform.pathSeparator}broken.json',
    );
    await invalidDraft.writeAsString('not json');

    expect(await store.consume('broken'), isNull);
    expect(await invalidDraft.exists(), isFalse);
  });

  test(
    'uses private notification visibility for notification listener flows',
    () {
      expect(
        transactionReviewNotificationDetails.visibility,
        NotificationVisibility.private,
      );
      expect(
        createdTransactionNotificationDetails.visibility,
        NotificationVisibility.private,
      );
    },
  );
}
