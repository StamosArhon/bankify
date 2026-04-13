import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/pages/home/transactions/filter_state.dart';
import 'package:bankify/preferences_store.dart';
import 'package:bankify/settings.dart';

void main() {
  group('TransactionFilterSnapshot', () {
    test('serializes and compares snapshots by value', () {
      const TransactionFilterSnapshot snapshot = TransactionFilterSnapshot(
        accountId: 'acc-1',
        accountName: 'Checking',
        text: 'coffee',
        currencyId: 'cur-1',
        currencyCode: 'EUR',
        currencyName: 'Euro',
        currencySymbol: '€',
        currencyDecimalPlaces: 2,
        categoryId: 'cat-1',
        categoryName: 'Food',
        budgetId: '-1',
        budgetName: '<No Budget set>',
        billId: 'bill-1',
        billName: 'Phone',
        tags: <String>['morning', 'work'],
      );

      final TransactionFilterSnapshot decoded =
          TransactionFilterSnapshot.fromJson(
            jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
          );

      expect(decoded, snapshot);
      expect(decoded.hasFilters, isTrue);
      expect(decoded.toCurrencyRead()?.attributes.code, 'EUR');
      expect(decoded.toBillRead()?.attributes.name, 'Phone');
    });
  });

  group('TransactionFilterPresetStore', () {
    test('persists presets newest-first and supports deletion', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final TransactionFilterPresetStore presetStore =
          TransactionFilterPresetStore(store: store);

      await presetStore.save(
        TransactionFilterPreset(
          id: 'older',
          name: 'Old',
          snapshot: const TransactionFilterSnapshot(text: 'old'),
          showFutureTransactions: false,
          dateFilter: TransactionDateFilter.all,
          updatedAt: DateTime.utc(2026, 4, 14, 10),
        ),
      );
      await presetStore.save(
        TransactionFilterPreset(
          id: 'newer',
          name: 'New',
          snapshot: const TransactionFilterSnapshot(text: 'new'),
          showFutureTransactions: true,
          dateFilter: TransactionDateFilter.last30Days,
          updatedAt: DateTime.utc(2026, 4, 14, 11),
        ),
      );

      final List<TransactionFilterPreset> loaded = await presetStore.load();

      expect(
        loaded.map((TransactionFilterPreset preset) => preset.id),
        <String>['newer', 'older'],
      );

      await presetStore.delete('newer');

      final List<TransactionFilterPreset> afterDelete =
          await presetStore.load();
      expect(
        afterDelete.map((TransactionFilterPreset preset) => preset.id),
        <String>['older'],
      );
    });
  });
}

class InMemoryPreferencesStore implements PreferencesStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
