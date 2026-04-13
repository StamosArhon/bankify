import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/transaction/editor_state_store.dart';
import 'package:bankify/preferences_store.dart';

void main() {
  group('TransactionEditorStateSnapshot', () {
    test('detects meaningful state and round-trips through json', () {
      final TransactionEditorStateSnapshot snapshot =
          TransactionEditorStateSnapshot(
            title: 'Lunch',
            ownAccountId: 'acc-1',
            transactionType: TransactionTypeProperty.withdrawal,
            date: DateTime.utc(2026, 4, 14, 12, 30),
            localCurrency: const TransactionEditorCurrencySnapshot(
              id: 'cur-1',
              code: 'EUR',
              symbol: '€',
              decimalPlaces: 2,
            ),
            reconciled: false,
            splitMode: false,
            showSourceAccountSelection: false,
            showDestinationAccountSelection: false,
            splits: const <TransactionEditorSplitSnapshot>[
              TransactionEditorSplitSnapshot(
                title: 'Lunch',
                sourceName: 'Checking',
                sourceType: AccountTypeProperty.assetAccount,
                destinationName: 'Cafe',
                destinationType: AccountTypeProperty.expenseAccount,
                localAmount: 12.5,
                foreignAmount: 0,
                foreignCurrency: null,
                categoryName: 'Food',
                budgetName: '',
                notes: 'weekday',
                tags: <String>['office'],
                billId: null,
                billName: null,
                piggyBankId: null,
                piggyBankName: null,
              ),
            ],
          );

      final TransactionEditorStateSnapshot decoded =
          TransactionEditorStateSnapshot.fromJson(snapshot.toJson());

      expect(decoded.hasMeaningfulData, isTrue);
      expect(decoded.title, 'Lunch');
      expect(decoded.splits.single.categoryName, 'Food');
      expect(decoded.localCurrency?.toCurrencyRead().attributes.code, 'EUR');
    });
  });

  group('TransactionEditorStateStore', () {
    test('stores draft envelopes and templates newest-first', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final TransactionEditorStateStore stateStore =
          TransactionEditorStateStore(store: store);
      final TransactionEditorStateSnapshot snapshot =
          TransactionEditorStateSnapshot(
            title: 'Dinner',
            ownAccountId: 'acc-1',
            transactionType: TransactionTypeProperty.withdrawal,
            date: DateTime.utc(2026, 4, 14, 18),
            localCurrency: null,
            reconciled: false,
            splitMode: false,
            showSourceAccountSelection: false,
            showDestinationAccountSelection: false,
            splits: const <TransactionEditorSplitSnapshot>[
              TransactionEditorSplitSnapshot(
                title: 'Dinner',
                sourceName: 'Checking',
                sourceType: AccountTypeProperty.assetAccount,
                destinationName: 'Restaurant',
                destinationType: AccountTypeProperty.expenseAccount,
                localAmount: 35,
                foreignAmount: 0,
                foreignCurrency: null,
                categoryName: '',
                budgetName: '',
                notes: '',
                tags: <String>[],
                billId: null,
                billName: null,
                piggyBankId: null,
                piggyBankName: null,
              ),
            ],
          );

      await stateStore.saveDraft(snapshot);
      final TransactionEditorDraftEnvelope? draft =
          await stateStore.loadDraft();
      expect(draft, isNotNull);
      expect(draft?.snapshot.title, 'Dinner');

      await stateStore.saveTemplate(
        StoredTransactionEditorTemplate(
          id: 'older',
          name: 'Older',
          snapshot: snapshot,
          updatedAt: DateTime.utc(2026, 4, 14, 10),
        ),
      );
      await stateStore.saveTemplate(
        StoredTransactionEditorTemplate(
          id: 'newer',
          name: 'Newer',
          snapshot: snapshot,
          updatedAt: DateTime.utc(2026, 4, 14, 11),
        ),
      );

      final List<StoredTransactionEditorTemplate> templates =
          await stateStore.loadTemplates();
      expect(
        templates.map(
          (StoredTransactionEditorTemplate template) => template.id,
        ),
        <String>['newer', 'older'],
      );

      await stateStore.deleteTemplate('newer');
      final List<StoredTransactionEditorTemplate> afterDelete =
          await stateStore.loadTemplates();
      expect(
        afterDelete.map(
          (StoredTransactionEditorTemplate template) => template.id,
        ),
        <String>['older'],
      );

      await stateStore.clearDraft();
      expect(await stateStore.loadDraft(), isNull);
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
