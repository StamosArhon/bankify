import 'package:collection/collection.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

class TransactionEditorSplitDraft {
  const TransactionEditorSplitDraft({
    required this.amount,
    required this.billId,
    required this.budgetName,
    required this.categoryName,
    required this.date,
    required this.description,
    required this.destinationName,
    required this.foreignAmount,
    required this.foreignCurrencyId,
    required this.notes,
    required this.order,
    required this.piggyBankId,
    required this.reconciled,
    required this.sourceName,
    required this.tags,
    required this.transactionJournalId,
    required this.type,
  });

  final double amount;
  final String billId;
  final String budgetName;
  final String categoryName;
  final DateTime date;
  final String description;
  final String destinationName;
  final double? foreignAmount;
  final String? foreignCurrencyId;
  final String notes;
  final int order;
  final int? piggyBankId;
  final bool reconciled;
  final String sourceName;
  final List<String> tags;
  final String? transactionJournalId;
  final TransactionTypeProperty type;
}

class TransactionEditorPayloadMapper {
  const TransactionEditorPayloadMapper._();

  static TransactionUpdate buildUpdate({
    required List<TransactionEditorSplitDraft> drafts,
    required List<TransactionSplit> existingSplits,
    required String? groupTitle,
  }) {
    return TransactionUpdate(
      groupTitle: groupTitle,
      transactions:
          drafts.map((TransactionEditorSplitDraft draft) {
            final TransactionSplitUpdate candidate = TransactionSplitUpdate(
              amount: draft.amount.toString(),
              billId: draft.billId,
              budgetName: draft.budgetName,
              categoryName: draft.categoryName,
              date: draft.date,
              description: draft.description,
              destinationName: draft.destinationName,
              foreignAmount:
                  draft.foreignCurrencyId != null
                      ? draft.foreignAmount?.toString() ?? "0"
                      : "0",
              foreignCurrencyId: draft.foreignCurrencyId,
              notes: draft.notes,
              order: draft.order,
              sourceName: draft.sourceName,
              tags: draft.tags,
              transactionJournalId: draft.transactionJournalId,
              type: draft.type,
              reconciled: draft.reconciled,
            );

            final TransactionSplit? oldSplit = existingSplits.firstWhereOrNull(
              (TransactionSplit split) =>
                  split.transactionJournalId == candidate.transactionJournalId,
            );
            if (oldSplit == null) {
              return candidate;
            }
            return txFilterSameFields(candidate, oldSplit);
          }).toList(),
    );
  }

  static TransactionStore buildStore({
    required List<TransactionEditorSplitDraft> drafts,
    required String? groupTitle,
  }) {
    return TransactionStore(
      groupTitle: groupTitle,
      transactions:
          drafts.map((TransactionEditorSplitDraft draft) {
            return TransactionSplitStore(
              type: draft.type,
              date: draft.date,
              amount: draft.amount.toString(),
              description: draft.description,
              billId: draft.billId,
              piggyBankId: draft.piggyBankId,
              budgetName: draft.budgetName,
              categoryName: draft.categoryName,
              destinationName: draft.destinationName,
              foreignAmount:
                  draft.foreignCurrencyId != null
                      ? draft.foreignAmount?.toString() ?? "0"
                      : "0",
              foreignCurrencyId: draft.foreignCurrencyId,
              notes: draft.notes,
              order: draft.order,
              sourceName: draft.sourceName,
              tags: draft.tags,
              reconciled: draft.reconciled,
            );
          }).toList(),
      applyRules: true,
      fireWebhooks: true,
      errorIfDuplicateHash: true,
    );
  }
}

TransactionSplitUpdate txFilterSameFields(
  TransactionSplitUpdate txU,
  TransactionSplit tx,
) {
  /* https://github.com/firefly-iii/firefly-iii/blob/main/app/Validation/GroupValidation.php#L105
     $forbidden = ['amount', 'foreign_amount', 'currency_code', 'currency_id', 'foreign_currency_code', 'foreign_currency_id',
       'source_id', 'source_name', 'source_number', 'source_iban',
       'destination_id', 'destination_name', 'destination_number', 'destination_iban',
     ];
       */
  final String? amount =
      (txU.amount == null ||
              double.parse(tx.amount) == double.parse(txU.amount!))
          ? null
          : txU.amount;
  String? foreignAmount;
  if (txU.foreignAmount != null) {
    if (tx.foreignAmount == null) {
      foreignAmount = txU.foreignAmount;
    } else if (double.parse(tx.foreignAmount!) ==
        double.parse(txU.foreignAmount!)) {
      foreignAmount = null;
    } else {
      foreignAmount = txU.foreignAmount;
    }
  }

  // Undo "HAX" from above if not needed (foreign currency was zero, is zero)
  if (tx.foreignCurrencyId == null &&
      txU.foreignCurrencyId == null &&
      foreignAmount == "0") {
    foreignAmount = null;
  }

  return txU.copyWithWrapped(
    amount: Wrapped<String?>.value(amount),
    foreignAmount: Wrapped<String?>.value(foreignAmount),
    foreignCurrencyId:
        tx.foreignCurrencyId == txU.foreignCurrencyId
            ? const Wrapped<String?>.value(null)
            : Wrapped<String?>.value(txU.foreignCurrencyId),
    sourceName:
        tx.sourceName == txU.sourceName
            ? const Wrapped<String?>.value(null)
            : Wrapped<String?>.value(txU.sourceName),
    destinationName:
        tx.destinationName == txU.destinationName
            ? const Wrapped<String?>.value(null)
            : Wrapped<String?>.value(txU.destinationName),
  );
}
