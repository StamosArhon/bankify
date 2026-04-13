import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/preferences_store.dart';

class TransactionEditorCurrencySnapshot {
  const TransactionEditorCurrencySnapshot({
    required this.id,
    required this.code,
    required this.symbol,
    this.decimalPlaces,
  });

  final String id;
  final String code;
  final String symbol;
  final int? decimalPlaces;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'code': code,
    'symbol': symbol,
    'decimalPlaces': decimalPlaces,
  };

  factory TransactionEditorCurrencySnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return TransactionEditorCurrencySnapshot(
      id: json['id'] as String? ?? '0',
      code: json['code'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      decimalPlaces: json['decimalPlaces'] as int?,
    );
  }

  CurrencyRead toCurrencyRead() => CurrencyRead(
    id: id,
    type: 'currencies',
    attributes: CurrencyProperties(
      code: code,
      name: code,
      symbol: symbol,
      decimalPlaces: decimalPlaces,
    ),
  );
}

class TransactionEditorSplitSnapshot {
  const TransactionEditorSplitSnapshot({
    required this.title,
    required this.sourceName,
    required this.sourceType,
    required this.destinationName,
    required this.destinationType,
    required this.localAmount,
    required this.foreignAmount,
    required this.foreignCurrency,
    required this.categoryName,
    required this.budgetName,
    required this.notes,
    required this.tags,
    required this.billId,
    required this.billName,
    required this.piggyBankId,
    required this.piggyBankName,
  });

  final String title;
  final String sourceName;
  final AccountTypeProperty sourceType;
  final String destinationName;
  final AccountTypeProperty destinationType;
  final double localAmount;
  final double foreignAmount;
  final TransactionEditorCurrencySnapshot? foreignCurrency;
  final String categoryName;
  final String budgetName;
  final String notes;
  final List<String> tags;
  final String? billId;
  final String? billName;
  final String? piggyBankId;
  final String? piggyBankName;

  bool get hasMeaningfulData =>
      title.trim().isNotEmpty ||
      sourceName.trim().isNotEmpty ||
      destinationName.trim().isNotEmpty ||
      localAmount != 0 ||
      foreignAmount != 0 ||
      categoryName.trim().isNotEmpty ||
      budgetName.trim().isNotEmpty ||
      notes.trim().isNotEmpty ||
      tags.isNotEmpty ||
      (billId?.isNotEmpty ?? false) ||
      (piggyBankId?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'sourceName': sourceName,
    'sourceType': sourceType.name,
    'destinationName': destinationName,
    'destinationType': destinationType.name,
    'localAmount': localAmount,
    'foreignAmount': foreignAmount,
    'foreignCurrency': foreignCurrency?.toJson(),
    'categoryName': categoryName,
    'budgetName': budgetName,
    'notes': notes,
    'tags': tags,
    'billId': billId,
    'billName': billName,
    'piggyBankId': piggyBankId,
    'piggyBankName': piggyBankName,
  };

  factory TransactionEditorSplitSnapshot.fromJson(Map<String, dynamic> json) {
    return TransactionEditorSplitSnapshot(
      title: json['title'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      sourceType: AccountTypeProperty.values.firstWhere(
        (AccountTypeProperty type) =>
            type.name == json['sourceType'] as String?,
        orElse: () => AccountTypeProperty.swaggerGeneratedUnknown,
      ),
      destinationName: json['destinationName'] as String? ?? '',
      destinationType: AccountTypeProperty.values.firstWhere(
        (AccountTypeProperty type) =>
            type.name == json['destinationType'] as String?,
        orElse: () => AccountTypeProperty.swaggerGeneratedUnknown,
      ),
      localAmount: (json['localAmount'] as num?)?.toDouble() ?? 0,
      foreignAmount: (json['foreignAmount'] as num?)?.toDouble() ?? 0,
      foreignCurrency:
          json['foreignCurrency'] is Map
              ? TransactionEditorCurrencySnapshot.fromJson(
                Map<String, dynamic>.from(
                  json['foreignCurrency'] as Map<dynamic, dynamic>,
                ),
              )
              : null,
      categoryName: json['categoryName'] as String? ?? '',
      budgetName: json['budgetName'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      tags: List<String>.from(json['tags'] as List<dynamic>? ?? <dynamic>[]),
      billId: json['billId'] as String?,
      billName: json['billName'] as String?,
      piggyBankId: json['piggyBankId'] as String?,
      piggyBankName: json['piggyBankName'] as String?,
    );
  }
}

class TransactionEditorStateSnapshot {
  const TransactionEditorStateSnapshot({
    required this.title,
    required this.ownAccountId,
    required this.transactionType,
    required this.date,
    required this.localCurrency,
    required this.reconciled,
    required this.splitMode,
    required this.showSourceAccountSelection,
    required this.showDestinationAccountSelection,
    required this.splits,
  });

  final String title;
  final String? ownAccountId;
  final TransactionTypeProperty transactionType;
  final DateTime date;
  final TransactionEditorCurrencySnapshot? localCurrency;
  final bool reconciled;
  final bool splitMode;
  final bool showSourceAccountSelection;
  final bool showDestinationAccountSelection;
  final List<TransactionEditorSplitSnapshot> splits;

  bool get hasMeaningfulData =>
      title.trim().isNotEmpty ||
      ownAccountId != null ||
      transactionType != TransactionTypeProperty.swaggerGeneratedUnknown ||
      reconciled ||
      splitMode ||
      showSourceAccountSelection ||
      showDestinationAccountSelection ||
      splits.any(
        (TransactionEditorSplitSnapshot split) => split.hasMeaningfulData,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'ownAccountId': ownAccountId,
    'transactionType': transactionType.name,
    'date': date.toIso8601String(),
    'localCurrency': localCurrency?.toJson(),
    'reconciled': reconciled,
    'splitMode': splitMode,
    'showSourceAccountSelection': showSourceAccountSelection,
    'showDestinationAccountSelection': showDestinationAccountSelection,
    'splits':
        splits
            .map((TransactionEditorSplitSnapshot split) => split.toJson())
            .toList(),
  };

  factory TransactionEditorStateSnapshot.fromJson(Map<String, dynamic> json) {
    return TransactionEditorStateSnapshot(
      title: json['title'] as String? ?? '',
      ownAccountId: json['ownAccountId'] as String?,
      transactionType: TransactionTypeProperty.values.firstWhere(
        (TransactionTypeProperty type) =>
            type.name == json['transactionType'] as String?,
        orElse: () => TransactionTypeProperty.swaggerGeneratedUnknown,
      ),
      date:
          DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      localCurrency:
          json['localCurrency'] is Map
              ? TransactionEditorCurrencySnapshot.fromJson(
                Map<String, dynamic>.from(
                  json['localCurrency'] as Map<dynamic, dynamic>,
                ),
              )
              : null,
      reconciled: json['reconciled'] as bool? ?? false,
      splitMode: json['splitMode'] as bool? ?? false,
      showSourceAccountSelection:
          json['showSourceAccountSelection'] as bool? ?? false,
      showDestinationAccountSelection:
          json['showDestinationAccountSelection'] as bool? ?? false,
      splits: (json['splits'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => TransactionEditorSplitSnapshot.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false),
    );
  }
}

class StoredTransactionEditorTemplate {
  const StoredTransactionEditorTemplate({
    required this.id,
    required this.name,
    required this.snapshot,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TransactionEditorStateSnapshot snapshot;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'snapshot': snapshot.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StoredTransactionEditorTemplate.fromJson(Map<String, dynamic> json) {
    return StoredTransactionEditorTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      snapshot: TransactionEditorStateSnapshot.fromJson(
        Map<String, dynamic>.from(json['snapshot'] as Map<dynamic, dynamic>),
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class TransactionEditorDraftEnvelope {
  const TransactionEditorDraftEnvelope({
    required this.snapshot,
    required this.savedAt,
  });

  final TransactionEditorStateSnapshot snapshot;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'snapshot': snapshot.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };

  factory TransactionEditorDraftEnvelope.fromJson(Map<String, dynamic> json) {
    return TransactionEditorDraftEnvelope(
      snapshot: TransactionEditorStateSnapshot.fromJson(
        Map<String, dynamic>.from(json['snapshot'] as Map<dynamic, dynamic>),
      ),
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class TransactionEditorStateStore {
  TransactionEditorStateStore({PreferencesStore? store})
    : _store = store ?? SharedPreferencesStore();

  static const String _draftKey = 'TX_EDITOR_DRAFT_V1';
  static const String _templateKey = 'TX_EDITOR_TEMPLATES_V1';
  final PreferencesStore _store;

  Future<TransactionEditorDraftEnvelope?> loadDraft() async {
    final String? raw = await _store.getString(_draftKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return TransactionEditorDraftEnvelope.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
      );
    } on FormatException {
      await _store.remove(_draftKey);
      return null;
    }
  }

  Future<void> saveDraft(TransactionEditorStateSnapshot snapshot) async {
    if (!snapshot.hasMeaningfulData) {
      await clearDraft();
      return;
    }
    await _store.setString(
      _draftKey,
      jsonEncode(
        TransactionEditorDraftEnvelope(
          snapshot: snapshot,
          savedAt: DateTime.now(),
        ).toJson(),
      ),
    );
  }

  Future<void> clearDraft() => _store.remove(_draftKey);

  Future<List<StoredTransactionEditorTemplate>> loadTemplates() async {
    final String? raw = await _store.getString(_templateKey);
    if (raw == null || raw.isEmpty) {
      return <StoredTransactionEditorTemplate>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => StoredTransactionEditorTemplate.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .sortedBy<DateTime>(
            (StoredTransactionEditorTemplate template) => template.updatedAt,
          )
          .reversed
          .toList();
    } on FormatException {
      await _store.remove(_templateKey);
      return <StoredTransactionEditorTemplate>[];
    }
  }

  Future<void> saveTemplate(StoredTransactionEditorTemplate template) async {
    final List<StoredTransactionEditorTemplate> templates =
        await loadTemplates();
    final int existingIndex = templates.indexWhere(
      (StoredTransactionEditorTemplate existing) => existing.id == template.id,
    );
    if (existingIndex >= 0) {
      templates[existingIndex] = template;
    } else {
      templates.add(template);
    }
    await _persistTemplates(templates);
  }

  Future<void> deleteTemplate(String id) async {
    final List<StoredTransactionEditorTemplate> templates =
        await loadTemplates();
    templates.removeWhere(
      (StoredTransactionEditorTemplate template) => template.id == id,
    );
    await _persistTemplates(templates);
  }

  Future<void> _persistTemplates(
    List<StoredTransactionEditorTemplate> templates,
  ) async {
    final List<StoredTransactionEditorTemplate> ordered = templates
        .sortedBy<DateTime>(
          (StoredTransactionEditorTemplate template) => template.updatedAt,
        )
        .reversed
        .toList(growable: false);
    await _store.setString(
      _templateKey,
      jsonEncode(
        ordered
            .map(
              (StoredTransactionEditorTemplate template) => template.toJson(),
            )
            .toList(),
      ),
    );
  }
}
