import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/transaction/payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionEditorPayloadMapper', () {
    test('buildStore maps draft fields into a store payload', () {
      final TransactionEditorSplitDraft draft = TransactionEditorSplitDraft(
        amount: 123.45,
        billId: 'bill-1',
        budgetName: 'Household',
        categoryName: 'Food',
        date: DateTime.utc(2026, 4, 13, 12),
        description: 'Lunch with the team',
        destinationName: 'Cafe',
        foreignAmount: 12.34,
        foreignCurrencyId: 'EUR',
        notes: 'receipt attached',
        order: 4,
        piggyBankId: 7,
        reconciled: true,
        sourceName: 'Checking',
        tags: const <String>['lunch', 'office'],
        transactionJournalId: 'journal-1',
        type: TransactionTypeProperty.withdrawal,
      );

      final TransactionStore payload =
          TransactionEditorPayloadMapper.buildStore(
            drafts: <TransactionEditorSplitDraft>[draft],
            groupTitle: 'Groceries',
          );

      expect(payload.groupTitle, 'Groceries');
      expect(payload.applyRules, isTrue);
      expect(payload.fireWebhooks, isTrue);
      expect(payload.errorIfDuplicateHash, isTrue);

      final TransactionSplitStore transaction = payload.transactions.single;
      expect(transaction.type, TransactionTypeProperty.withdrawal);
      expect(transaction.date, draft.date);
      expect(transaction.amount, '123.45');
      expect(transaction.description, 'Lunch with the team');
      expect(transaction.billId, 'bill-1');
      expect(transaction.piggyBankId, 7);
      expect(transaction.budgetName, 'Household');
      expect(transaction.categoryName, 'Food');
      expect(transaction.destinationName, 'Cafe');
      expect(transaction.foreignAmount, '12.34');
      expect(transaction.foreignCurrencyId, 'EUR');
      expect(transaction.notes, 'receipt attached');
      expect(transaction.order, 4);
      expect(transaction.sourceName, 'Checking');
      expect(transaction.tags, const <String>['lunch', 'office']);
      expect(transaction.reconciled, isTrue);
    });

    test(
      'buildUpdate nulls unchanged amount, source, destination, and zero foreign amount',
      () {
        final TransactionSplit existingSplit = TransactionSplit(
          transactionJournalId: 'journal-1',
          type: TransactionTypeProperty.withdrawal,
          date: DateTime.utc(2026, 4, 13, 12),
          amount: '123.45',
          description: 'Lunch with the team',
          sourceName: 'Checking',
          destinationName: 'Cafe',
        );

        final TransactionEditorSplitDraft draft = TransactionEditorSplitDraft(
          amount: 123.45,
          billId: 'bill-1',
          budgetName: 'Household',
          categoryName: 'Food',
          date: DateTime.utc(2026, 4, 13, 12),
          description: 'Lunch with the team',
          destinationName: 'Cafe',
          foreignAmount: null,
          foreignCurrencyId: null,
          notes: 'receipt attached',
          order: 4,
          piggyBankId: 7,
          reconciled: true,
          sourceName: 'Checking',
          tags: const <String>['lunch', 'office'],
          transactionJournalId: 'journal-1',
          type: TransactionTypeProperty.withdrawal,
        );

        final TransactionUpdate payload =
            TransactionEditorPayloadMapper.buildUpdate(
              drafts: <TransactionEditorSplitDraft>[draft],
              existingSplits: <TransactionSplit>[existingSplit],
              groupTitle: 'Groceries',
            );

        expect(payload.groupTitle, 'Groceries');
        final TransactionSplitUpdate transaction = payload.transactions!.single;
        expect(transaction.transactionJournalId, 'journal-1');
        expect(transaction.amount, isNull);
        expect(transaction.sourceName, isNull);
        expect(transaction.destinationName, isNull);
        expect(transaction.foreignAmount, isNull);
        expect(transaction.foreignCurrencyId, isNull);
      },
    );

    test(
      'txFilterSameFields removes unchanged values and normalizes zero foreign amount',
      () {
        final TransactionSplit existingSplit = TransactionSplit(
          transactionJournalId: 'journal-2',
          type: TransactionTypeProperty.withdrawal,
          date: DateTime.utc(2026, 4, 13, 12),
          amount: '10.00',
          description: 'Coffee',
          sourceName: 'Checking',
          destinationName: 'Cafe',
        );

        final TransactionSplitUpdate candidate = TransactionSplitUpdate(
          transactionJournalId: 'journal-2',
          type: TransactionTypeProperty.withdrawal,
          date: DateTime.utc(2026, 4, 13, 12),
          amount: '10.00',
          description: 'Coffee',
          foreignAmount: '0',
          foreignCurrencyId: null,
          sourceName: 'Checking',
          destinationName: 'Cafe',
        );

        final TransactionSplitUpdate filtered = txFilterSameFields(
          candidate,
          existingSplit,
        );

        expect(filtered.amount, isNull);
        expect(filtered.sourceName, isNull);
        expect(filtered.destinationName, isNull);
        expect(filtered.foreignAmount, isNull);
        expect(filtered.foreignCurrencyId, isNull);
      },
    );
  });
}
