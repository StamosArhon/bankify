import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/preferences_store.dart';
import 'package:bankify/settings.dart';

class TransactionFilterSnapshot {
  const TransactionFilterSnapshot({
    this.accountId,
    this.accountName,
    this.text,
    this.currencyId,
    this.currencyCode,
    this.currencyName,
    this.currencySymbol,
    this.currencyDecimalPlaces,
    this.categoryId,
    this.categoryName,
    this.budgetId,
    this.budgetName,
    this.billId,
    this.billName,
    this.tags = const <String>[],
  });

  final String? accountId;
  final String? accountName;
  final String? text;
  final String? currencyId;
  final String? currencyCode;
  final String? currencyName;
  final String? currencySymbol;
  final int? currencyDecimalPlaces;
  final String? categoryId;
  final String? categoryName;
  final String? budgetId;
  final String? budgetName;
  final String? billId;
  final String? billName;
  final List<String> tags;

  bool get hasFilters =>
      (accountId?.isNotEmpty ?? false) ||
      (text?.isNotEmpty ?? false) ||
      (currencyCode?.isNotEmpty ?? false) ||
      (categoryId?.isNotEmpty ?? false) ||
      (budgetId?.isNotEmpty ?? false) ||
      (billId?.isNotEmpty ?? false) ||
      tags.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accountId': accountId,
    'accountName': accountName,
    'text': text,
    'currencyId': currencyId,
    'currencyCode': currencyCode,
    'currencyName': currencyName,
    'currencySymbol': currencySymbol,
    'currencyDecimalPlaces': currencyDecimalPlaces,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'budgetId': budgetId,
    'budgetName': budgetName,
    'billId': billId,
    'billName': billName,
    'tags': tags,
  };

  factory TransactionFilterSnapshot.fromJson(Map<String, dynamic> json) {
    return TransactionFilterSnapshot(
      accountId: json['accountId'] as String?,
      accountName: json['accountName'] as String?,
      text: json['text'] as String?,
      currencyId: json['currencyId'] as String?,
      currencyCode: json['currencyCode'] as String?,
      currencyName: json['currencyName'] as String?,
      currencySymbol: json['currencySymbol'] as String?,
      currencyDecimalPlaces: json['currencyDecimalPlaces'] as int?,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      budgetId: json['budgetId'] as String?,
      budgetName: json['budgetName'] as String?,
      billId: json['billId'] as String?,
      billName: json['billName'] as String?,
      tags: List<String>.from(json['tags'] as List<dynamic>? ?? <dynamic>[]),
    );
  }

  AccountRead? toAccountRead() {
    if (!(accountId?.isNotEmpty ?? false)) {
      return null;
    }
    return AccountRead(
      id: accountId!,
      type: 'accounts',
      attributes: AccountProperties(
        name: accountName ?? '',
        type: ShortAccountTypeProperty.asset,
      ),
    );
  }

  CurrencyRead? toCurrencyRead() {
    if (!(currencyId?.isNotEmpty ?? false) &&
        !(currencyCode?.isNotEmpty ?? false)) {
      return null;
    }
    return CurrencyRead(
      id: currencyId ?? '0',
      type: 'currencies',
      attributes: CurrencyProperties(
        code: currencyCode ?? '',
        name: currencyName ?? currencyCode ?? '',
        symbol: currencySymbol ?? '',
        decimalPlaces: currencyDecimalPlaces,
      ),
    );
  }

  CategoryRead? toCategoryRead() {
    if (!(categoryId?.isNotEmpty ?? false)) {
      return null;
    }
    return CategoryRead(
      id: categoryId!,
      type: 'categories',
      attributes: CategoryProperties(name: categoryName ?? ''),
    );
  }

  BudgetRead? toBudgetRead() {
    if (!(budgetId?.isNotEmpty ?? false)) {
      return null;
    }
    return BudgetRead(
      id: budgetId!,
      type: 'budgets',
      attributes: BudgetProperties(name: budgetName ?? ''),
    );
  }

  BillRead? toBillRead() {
    if (!(billId?.isNotEmpty ?? false)) {
      return null;
    }
    return BillRead(
      id: billId!,
      type: 'bills',
      attributes: BillProperties(
        amountMin: '0',
        amountMax: '0',
        date: DateTime.fromMillisecondsSinceEpoch(0),
        repeatFreq: BillRepeatFrequency.swaggerGeneratedUnknown,
        name: billName ?? '',
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TransactionFilterSnapshot &&
        other.accountId == accountId &&
        other.accountName == accountName &&
        other.text == text &&
        other.currencyId == currencyId &&
        other.currencyCode == currencyCode &&
        other.currencyName == currencyName &&
        other.currencySymbol == currencySymbol &&
        other.currencyDecimalPlaces == currencyDecimalPlaces &&
        other.categoryId == categoryId &&
        other.categoryName == categoryName &&
        other.budgetId == budgetId &&
        other.budgetName == budgetName &&
        other.billId == billId &&
        other.billName == billName &&
        const ListEquality<String>().equals(other.tags, tags);
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    accountName,
    text,
    currencyId,
    currencyCode,
    currencyName,
    currencySymbol,
    currencyDecimalPlaces,
    categoryId,
    categoryName,
    budgetId,
    budgetName,
    billId,
    billName,
    const ListEquality<String>().hash(tags),
  );
}

class TransactionFilterPreset {
  const TransactionFilterPreset({
    required this.id,
    required this.name,
    required this.snapshot,
    required this.showFutureTransactions,
    required this.dateFilter,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TransactionFilterSnapshot snapshot;
  final bool showFutureTransactions;
  final TransactionDateFilter dateFilter;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'snapshot': snapshot.toJson(),
    'showFutureTransactions': showFutureTransactions,
    'dateFilter': dateFilter.name,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TransactionFilterPreset.fromJson(Map<String, dynamic> json) {
    return TransactionFilterPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      snapshot: TransactionFilterSnapshot.fromJson(
        Map<String, dynamic>.from(json['snapshot'] as Map<dynamic, dynamic>),
      ),
      showFutureTransactions: json['showFutureTransactions'] as bool? ?? false,
      dateFilter: TransactionDateFilter.values.firstWhere(
        (TransactionDateFilter filter) =>
            filter.name == json['dateFilter'] as String?,
        orElse: () => TransactionDateFilter.all,
      ),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class TransactionFilterDialogResult {
  const TransactionFilterDialogResult({
    required this.snapshot,
    required this.showFutureTransactions,
    required this.dateFilter,
  });

  final TransactionFilterSnapshot snapshot;
  final bool showFutureTransactions;
  final TransactionDateFilter dateFilter;
}

class TransactionFilterPresetStore {
  TransactionFilterPresetStore({PreferencesStore? store})
    : _store = store ?? SharedPreferencesStore();

  static const String _storageKey = 'TX_FILTER_PRESETS';
  final PreferencesStore _store;

  Future<List<TransactionFilterPreset>> load() async {
    final String? raw = await _store.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <TransactionFilterPreset>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => TransactionFilterPreset.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .sortedBy<DateTime>(
            (TransactionFilterPreset preset) => preset.updatedAt,
          )
          .reversed
          .toList();
    } on FormatException {
      await _store.remove(_storageKey);
      return <TransactionFilterPreset>[];
    }
  }

  Future<void> save(TransactionFilterPreset preset) async {
    final List<TransactionFilterPreset> presets = await load();
    final int existingIndex = presets.indexWhere(
      (TransactionFilterPreset existing) => existing.id == preset.id,
    );
    if (existingIndex >= 0) {
      presets[existingIndex] = preset;
    } else {
      presets.add(preset);
    }
    await _persist(presets);
  }

  Future<void> delete(String id) async {
    final List<TransactionFilterPreset> presets = await load();
    presets.removeWhere((TransactionFilterPreset preset) => preset.id == id);
    await _persist(presets);
  }

  Future<void> _persist(List<TransactionFilterPreset> presets) async {
    final List<TransactionFilterPreset> ordered = presets
        .sortedBy<DateTime>(
          (TransactionFilterPreset preset) => preset.updatedAt,
        )
        .reversed
        .toList(growable: false);
    await _store.setString(
      _storageKey,
      jsonEncode(
        ordered
            .map((TransactionFilterPreset preset) => preset.toJson())
            .toList(),
      ),
    );
  }
}
