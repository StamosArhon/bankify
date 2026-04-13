import 'dart:async';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/home/transactions/filter_state.dart';
import 'package:bankify/pages/transaction/tags.dart';
import 'package:bankify/settings.dart';

final Logger log = Logger("Pages.Home.Transaction.Filter");

class TransactionFilters with ChangeNotifier {
  TransactionFilters({
    this.account,
    this.text,
    this.currency,
    this.category,
    this.budget,
    this.bill,
    this.tags,
  }) {
    tags ??= Tags();
    updateFilters(notify: false);
  }

  AccountRead? account;
  String? text;
  CurrencyRead? currency;
  CategoryRead? category;
  BudgetRead? budget;
  BillRead? bill;
  Tags? tags;

  bool _hasFilters = false;
  bool get hasFilters => _hasFilters;

  TransactionFilterSnapshot toSnapshot() => TransactionFilterSnapshot(
    accountId: account?.id,
    accountName: account?.attributes.name,
    text: text,
    currencyId: currency?.id,
    currencyCode: currency?.attributes.code,
    currencyName: currency?.attributes.name,
    currencySymbol: currency?.attributes.symbol,
    currencyDecimalPlaces: currency?.attributes.decimalPlaces,
    categoryId: category?.id,
    categoryName: category?.attributes.name,
    budgetId: budget?.id,
    budgetName: budget?.attributes.name,
    billId: bill?.id,
    billName: bill?.attributes.name,
    tags: List<String>.from(tags?.tags ?? <String>[]),
  );

  TransactionFilters clone() {
    final TransactionFilters cloned = TransactionFilters();
    cloned.applySnapshot(toSnapshot(), notify: false);
    return cloned;
  }

  bool sameAs(TransactionFilters other) => toSnapshot() == other.toSnapshot();

  void applySnapshot(TransactionFilterSnapshot snapshot, {bool notify = true}) {
    account = snapshot.toAccountRead();
    text =
        (snapshot.text?.trim().isEmpty ?? true) ? null : snapshot.text?.trim();
    currency = snapshot.toCurrencyRead();
    category = snapshot.toCategoryRead();
    budget = snapshot.toBudgetRead();
    bill = snapshot.toBillRead();
    tags = Tags(List<String>.from(snapshot.tags));
    updateFilters(notify: notify);
  }

  TransactionFilters copyWith({
    AccountRead? account,
    String? text,
    CurrencyRead? currency,
    CategoryRead? category,
    BudgetRead? budget,
    BillRead? bill,
    Tags? tags,
  }) {
    return TransactionFilters(
      account: account ?? this.account,
      text: text ?? this.text,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      budget: budget ?? this.budget,
      bill: bill ?? this.bill,
      tags: Tags(
        List<String>.from(tags?.tags ?? this.tags?.tags ?? <String>[]),
      ),
    );
  }

  void updateFilters({bool notify = true}) {
    _hasFilters =
        account != null ||
        (text?.trim().isNotEmpty ?? false) ||
        currency != null ||
        category != null ||
        budget != null ||
        bill != null ||
        (tags?.tags.isNotEmpty ?? false);
    if (notify) {
      log.finest(() => "notify TransactionFilters, filters? $hasFilters");
      notifyListeners();
    }
  }

  void reset({bool notify = true}) {
    account = null;
    text = null;
    currency = null;
    category = null;
    budget = null;
    bill = null;
    tags = Tags();
    updateFilters(notify: notify);
  }
}

class FilterData {
  FilterData(
    this.accounts,
    this.currencies,
    this.categories,
    this.budgets,
    this.bills,
  );

  final List<AccountRead> accounts;
  final List<CurrencyRead> currencies;
  final List<CategoryRead> categories;
  final List<BudgetRead> budgets;
  final List<BillRead> bills;
}

class FilterDialog extends StatefulWidget {
  const FilterDialog({
    super.key,
    required this.initialFilters,
    required this.initialShowFutureTransactions,
    required this.initialDateFilter,
  });

  final TransactionFilters initialFilters;
  final bool initialShowFutureTransactions;
  final TransactionDateFilter initialDateFilter;

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final Logger _dialogLog = Logger("Pages.Home.Transaction.Filter.Dialog");
  final TransactionFilterPresetStore _presetStore =
      TransactionFilterPresetStore();
  final TextEditingController _searchTextController = TextEditingController();
  final TextEditingController _tagsTextController = TextEditingController();

  late final TransactionFilters _draftFilters;
  late final Future<FilterData> _dataFuture;
  late bool _showFutureTransactions;
  late TransactionDateFilter _dateFilter;
  List<TransactionFilterPreset> _presets = <TransactionFilterPreset>[];

  @override
  void initState() {
    super.initState();

    _draftFilters = widget.initialFilters.clone();
    _showFutureTransactions = widget.initialShowFutureTransactions;
    _dateFilter = widget.initialDateFilter;
    _searchTextController.text = _draftFilters.text ?? '';
    _syncTagsTextController();
    _dataFuture = _getData(context);
    unawaited(_loadPresets());
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _tagsTextController.dispose();
    super.dispose();
  }

  Future<FilterData> _getData(BuildContext context) async {
    final FireflyIii api = context.read<FireflyService>().api;

    final (
      Response<AccountArray> respAccounts,
      Response<CurrencyArray> respCurrencies,
      Response<CategoryArray> respCats,
      Response<BudgetArray> respBudgets,
      Response<BillArray> respBills,
    ) = await (
          api.v1AccountsGet(type: AccountTypeFilter.assetAccount),
          api.v1CurrenciesGet(),
          api.v1CategoriesGet(),
          api.v1BudgetsGet(),
          api.v1BillsGet(),
        ).wait;
    apiThrowErrorIfEmpty(respAccounts, context.mounted ? context : null);
    apiThrowErrorIfEmpty(respCurrencies, context.mounted ? context : null);
    apiThrowErrorIfEmpty(respCats, context.mounted ? context : null);
    apiThrowErrorIfEmpty(respBudgets, context.mounted ? context : null);
    apiThrowErrorIfEmpty(respBills, context.mounted ? context : null);

    return FilterData(
      respAccounts.body!.data,
      respCurrencies.body!.data,
      respCats.body!.data,
      respBudgets.body!.data,
      respBills.body!.data,
    );
  }

  Future<void> _loadPresets() async {
    final List<TransactionFilterPreset> presets = await _presetStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _presets = presets;
    });
  }

  void _syncTagsTextController() {
    _tagsTextController.text =
        (_draftFilters.tags?.tags.isNotEmpty ?? false) ? " " : "";
  }

  TransactionFilterDialogResult _buildResult() {
    _draftFilters.text =
        _searchTextController.text.trim().isEmpty
            ? null
            : _searchTextController.text.trim();
    _draftFilters.updateFilters(notify: false);
    return TransactionFilterDialogResult(
      snapshot: _draftFilters.toSnapshot(),
      showFutureTransactions: _showFutureTransactions,
      dateFilter: _dateFilter,
    );
  }

  bool get _canSavePreset {
    final TransactionFilterDialogResult result = _buildResult();
    return result.snapshot.hasFilters ||
        result.showFutureTransactions ||
        result.dateFilter != TransactionDateFilter.all;
  }

  void _resetDraft() {
    setState(() {
      _draftFilters.reset(notify: false);
      _showFutureTransactions = false;
      _dateFilter = TransactionDateFilter.all;
      _searchTextController.clear();
      _syncTagsTextController();
    });
  }

  void _applyPreset(TransactionFilterPreset preset) {
    setState(() {
      _draftFilters.applySnapshot(preset.snapshot, notify: false);
      _showFutureTransactions = preset.showFutureTransactions;
      _dateFilter = preset.dateFilter;
      _searchTextController.text = _draftFilters.text ?? '';
      _syncTagsTextController();
    });
  }

  Future<void> _deletePreset(TransactionFilterPreset preset) async {
    await _presetStore.delete(preset.id);
    await _loadPresets();
  }

  Future<void> _savePreset() async {
    final String? presetName = await _showPresetNameDialog();
    if (!mounted || presetName == null) {
      return;
    }

    final TransactionFilterDialogResult result = _buildResult();
    String? existingId;
    for (final TransactionFilterPreset preset in _presets) {
      if (preset.name.toLowerCase() == presetName.toLowerCase()) {
        existingId = preset.id;
        break;
      }
    }

    await _presetStore.save(
      TransactionFilterPreset(
        id: existingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: presetName,
        snapshot: result.snapshot,
        showFutureTransactions: result.showFutureTransactions,
        dateFilter: result.dateFilter,
        updatedAt: DateTime.now(),
      ),
    );
    await _loadPresets();
  }

  Future<String?> _showPresetNameDialog() async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.bookmark_add_outlined),
          title: Text(S.of(context).homeTransactionsPresetSaveTitle),
          clipBehavior: Clip.hardEdge,
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: S.of(context).homeTransactionsPresetNameLabel,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                final String name = controller.text.trim();
                Navigator.of(context).pop(name.isEmpty ? null : name);
              },
              child: Text(MaterialLocalizations.of(context).saveButtonLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  List<Widget> _buildPresetSection(BuildContext context) {
    if (_presets.isEmpty) {
      return <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _canSavePreset ? _savePreset : null,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(S.of(context).homeTransactionsPresetSaveAction),
          ),
        ),
        const SizedBox(height: 12),
      ];
    }

    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              S.of(context).homeTransactionsPresetSectionTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton.icon(
            onPressed: _canSavePreset ? _savePreset : null,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(S.of(context).homeTransactionsPresetSaveAction),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _presets
            .map(
              (TransactionFilterPreset preset) => InputChip(
                label: Text(preset.name),
                onPressed: () => _applyPreset(preset),
                onDeleted: () => _deletePreset(preset),
              ),
            )
            .toList(growable: false),
      ),
      const SizedBox(height: 12),
    ];
  }

  AccountRead _accountAllOption(BuildContext context) {
    return AccountRead(
      id: "0",
      type: "dummy",
      attributes: AccountProperties(
        name: S.of(context).homeTransactionsDialogFilterAccountsAll,
        type: ShortAccountTypeProperty.swaggerGeneratedUnknown,
      ),
    );
  }

  CurrencyRead _currencyAllOption(BuildContext context) {
    return CurrencyRead(
      id: "0",
      type: "dummy",
      attributes: CurrencyProperties(
        name: S.of(context).homeTransactionsDialogFilterCurrenciesAll,
        code: "",
        symbol: "",
      ),
    );
  }

  CategoryRead _categoryOption(BuildContext context, String id, String name) {
    return CategoryRead(
      id: id,
      type: "dummy",
      attributes: CategoryProperties(name: name),
    );
  }

  BudgetRead _budgetOption(BuildContext context, String id, String name) {
    return BudgetRead(
      id: id,
      type: "dummy",
      attributes: BudgetProperties(name: name),
    );
  }

  BillRead _billOption(BuildContext context, String id, String name) {
    return BillRead(
      id: id,
      type: "dummy",
      attributes: BillProperties(
        amountMax: "0",
        amountMin: "0",
        date: DateTime.now(),
        repeatFreq: BillRepeatFrequency.swaggerGeneratedUnknown,
        name: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _dialogLog.finest(() => "build()");

    return AlertDialog(
      icon: const Icon(Icons.tune),
      title: Text(S.of(context).homeTransactionsDialogFilterTitle),
      clipBehavior: Clip.hardEdge,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        OutlinedButton(
          onPressed: _resetDraft,
          child: Text(S.of(context).generalReset),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
      content: SingleChildScrollView(
        child: FutureBuilder<FilterData>(
          future: _dataFuture,
          builder: (BuildContext context, AsyncSnapshot<FilterData> snapshot) {
            if (snapshot.hasError) {
              _dialogLog.severe(
                "error getting filter data",
                snapshot.error,
                snapshot.stackTrace,
              );
              return Text(S.of(context).generalError);
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final double inputWidth =
                MediaQuery.of(context).size.width - 128 - 24;
            final FilterData data = snapshot.data!;
            final List<Widget> children = <Widget>[
              ..._buildPresetSection(context),
              SizedBox(
                width: inputWidth,
                child: CheckboxListTile(
                  title: Text(
                    S
                        .of(context)
                        .homeTransactionsDialogFilterFutureTransactions,
                  ),
                  value: _showFutureTransactions,
                  onChanged:
                      (bool? value) => setState(() {
                        _showFutureTransactions = value ?? false;
                      }),
                ),
              ),
              const SizedBox(height: 12),
              DropdownMenu<TransactionDateFilter>(
                key: ValueKey<String>('date-filter-${_dateFilter.name}'),
                initialSelection: _dateFilter,
                leadingIcon: const Icon(Icons.date_range),
                label: Text(
                  S.of(context).homeTransactionsDialogFilterDateRange,
                ),
                dropdownMenuEntries: TransactionDateFilter.values
                    .map(
                      (TransactionDateFilter filter) =>
                          DropdownMenuEntry<TransactionDateFilter>(
                            value: filter,
                            label: _getFilterName(context, filter),
                          ),
                    )
                    .toList(growable: false),
                onSelected: (TransactionDateFilter? newValue) {
                  if (newValue == null) {
                    return;
                  }
                  setState(() {
                    _dateFilter = newValue;
                  });
                },
                width: inputWidth,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: inputWidth,
                child: TextFormField(
                  controller: _searchTextController,
                  decoration: InputDecoration(
                    filled: false,
                    border: const OutlineInputBorder(),
                    labelText: S.of(context).homeTransactionsDialogFilterSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildAccountMenu(context, data, inputWidth),
              const SizedBox(height: 12),
              _buildCurrencyMenu(context, data, inputWidth),
              const SizedBox(height: 12),
              _buildCategoryMenu(context, data, inputWidth),
              const SizedBox(height: 12),
              _buildBudgetMenu(context, data, inputWidth),
              const SizedBox(height: 12),
              _buildBillMenu(context, data, inputWidth),
              const SizedBox(height: 12),
              TransactionTags(
                textController: _tagsTextController,
                tagsController: _draftFilters.tags ??= Tags(),
                enableAdd: false,
              ),
            ];

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountMenu(
    BuildContext context,
    FilterData data,
    double width,
  ) {
    final AccountRead allOption = _accountAllOption(context);
    final List<DropdownMenuEntry<AccountRead>> accountOptions =
        <DropdownMenuEntry<AccountRead>>[
          DropdownMenuEntry<AccountRead>(
            value: allOption,
            label: S.of(context).homeTransactionsDialogFilterAccountsAll,
          ),
          ...data.accounts.map(
            (AccountRead account) => DropdownMenuEntry<AccountRead>(
              value: account,
              label: account.attributes.name,
            ),
          ),
        ];

    final AccountRead currentAccount = data.accounts.firstWhere(
      (AccountRead account) => account.id == _draftFilters.account?.id,
      orElse: () => allOption,
    );

    return DropdownMenu<AccountRead>(
      key: ValueKey<String>('account-${currentAccount.id}'),
      initialSelection: currentAccount,
      leadingIcon: const Icon(Icons.account_balance),
      label: Text(S.of(context).generalAccount),
      dropdownMenuEntries: accountOptions,
      onSelected: (AccountRead? account) {
        setState(() {
          _draftFilters.account = (account?.id ?? "0") == "0" ? null : account;
        });
      },
      width: width,
    );
  }

  Widget _buildCurrencyMenu(
    BuildContext context,
    FilterData data,
    double width,
  ) {
    final CurrencyRead allOption = _currencyAllOption(context);
    final List<CurrencyRead> enabledCurrencies = data.currencies
        .where((CurrencyRead currency) => currency.attributes.enabled ?? false)
        .toList(growable: false);
    final List<DropdownMenuEntry<CurrencyRead>> currencyOptions =
        <DropdownMenuEntry<CurrencyRead>>[
          DropdownMenuEntry<CurrencyRead>(
            value: allOption,
            label: S.of(context).homeTransactionsDialogFilterCurrenciesAll,
          ),
          ...enabledCurrencies.map(
            (CurrencyRead currency) => DropdownMenuEntry<CurrencyRead>(
              value: currency,
              label: currency.attributes.name,
            ),
          ),
        ];

    final CurrencyRead currentCurrency = enabledCurrencies.firstWhere(
      (CurrencyRead currency) => currency.id == _draftFilters.currency?.id,
      orElse: () => allOption,
    );

    return DropdownMenu<CurrencyRead>(
      key: ValueKey<String>('currency-${currentCurrency.id}'),
      initialSelection: currentCurrency,
      leadingIcon: const Icon(Icons.money),
      label: Text(S.of(context).generalCurrency),
      dropdownMenuEntries: currencyOptions,
      onSelected: (CurrencyRead? currency) {
        setState(() {
          _draftFilters.currency =
              (currency?.id ?? "0") == "0" ? null : currency;
        });
      },
      width: width,
    );
  }

  Widget _buildCategoryMenu(
    BuildContext context,
    FilterData data,
    double width,
  ) {
    final CategoryRead allOption = _categoryOption(
      context,
      "0",
      S.of(context).homeTransactionsDialogFilterCategoriesAll,
    );
    final CategoryRead unsetOption = _categoryOption(
      context,
      "-1",
      S.of(context).homeTransactionsDialogFilterCategoryUnset,
    );
    final List<DropdownMenuEntry<CategoryRead>> categoryOptions =
        <DropdownMenuEntry<CategoryRead>>[
          DropdownMenuEntry<CategoryRead>(
            value: allOption,
            label: S.of(context).homeTransactionsDialogFilterCategoriesAll,
          ),
          DropdownMenuEntry<CategoryRead>(
            value: unsetOption,
            label: S.of(context).homeTransactionsDialogFilterCategoryUnset,
          ),
          ...data.categories.map(
            (CategoryRead category) => DropdownMenuEntry<CategoryRead>(
              value: category,
              label: category.attributes.name,
            ),
          ),
        ];

    final CategoryRead currentCategory = data.categories.firstWhere(
      (CategoryRead category) => category.id == _draftFilters.category?.id,
      orElse:
          () => _draftFilters.category?.id == "-1" ? unsetOption : allOption,
    );

    return DropdownMenu<CategoryRead>(
      key: ValueKey<String>('category-${currentCategory.id}'),
      initialSelection: currentCategory,
      leadingIcon: const Icon(Icons.assignment),
      label: Text(S.of(context).generalCategory),
      dropdownMenuEntries: categoryOptions,
      onSelected: (CategoryRead? category) {
        setState(() {
          _draftFilters.category =
              (category?.id ?? "0") == "0" ? null : category;
        });
      },
      width: width,
    );
  }

  Widget _buildBudgetMenu(BuildContext context, FilterData data, double width) {
    final BudgetRead allOption = _budgetOption(
      context,
      "0",
      S.of(context).homeTransactionsDialogFilterBudgetsAll,
    );
    final BudgetRead unsetOption = _budgetOption(
      context,
      "-1",
      S.of(context).homeTransactionsDialogFilterBudgetUnset,
    );
    final List<DropdownMenuEntry<BudgetRead>> budgetOptions =
        <DropdownMenuEntry<BudgetRead>>[
          DropdownMenuEntry<BudgetRead>(
            value: allOption,
            label: S.of(context).homeTransactionsDialogFilterBudgetsAll,
          ),
          DropdownMenuEntry<BudgetRead>(
            value: unsetOption,
            label: S.of(context).homeTransactionsDialogFilterBudgetUnset,
          ),
          ...data.budgets.map(
            (BudgetRead budget) => DropdownMenuEntry<BudgetRead>(
              value: budget,
              label: budget.attributes.name,
            ),
          ),
        ];

    final BudgetRead currentBudget = data.budgets.firstWhere(
      (BudgetRead budget) => budget.id == _draftFilters.budget?.id,
      orElse: () => _draftFilters.budget?.id == "-1" ? unsetOption : allOption,
    );

    return DropdownMenu<BudgetRead>(
      key: ValueKey<String>('budget-${currentBudget.id}'),
      initialSelection: currentBudget,
      leadingIcon: const Icon(Icons.payments),
      label: Text(S.of(context).generalBudget),
      dropdownMenuEntries: budgetOptions,
      onSelected: (BudgetRead? budget) {
        setState(() {
          _draftFilters.budget = (budget?.id ?? "0") == "0" ? null : budget;
        });
      },
      width: width,
    );
  }

  Widget _buildBillMenu(BuildContext context, FilterData data, double width) {
    final BillRead allOption = _billOption(
      context,
      "0",
      S.of(context).homeTransactionsDialogFilterBillsAll,
    );
    final BillRead unsetOption = _billOption(
      context,
      "-1",
      S.of(context).homeTransactionsDialogFilterBillUnset,
    );
    final List<DropdownMenuEntry<BillRead>> billOptions =
        <DropdownMenuEntry<BillRead>>[
          DropdownMenuEntry<BillRead>(
            value: allOption,
            label: S.of(context).homeTransactionsDialogFilterBillsAll,
          ),
          DropdownMenuEntry<BillRead>(
            value: unsetOption,
            label: S.of(context).homeTransactionsDialogFilterBillUnset,
          ),
          ...data.bills.map(
            (BillRead bill) => DropdownMenuEntry<BillRead>(
              value: bill,
              label: bill.attributes.name ?? "",
            ),
          ),
        ];

    final BillRead currentBill = data.bills.firstWhere(
      (BillRead bill) => bill.id == _draftFilters.bill?.id,
      orElse: () => _draftFilters.bill?.id == "-1" ? unsetOption : allOption,
    );

    return DropdownMenu<BillRead>(
      key: ValueKey<String>('bill-${currentBill.id}'),
      initialSelection: currentBill,
      leadingIcon: const Icon(Icons.calendar_today),
      label: Text(S.of(context).generalBill),
      dropdownMenuEntries: billOptions,
      onSelected: (BillRead? bill) {
        setState(() {
          _draftFilters.bill = (bill?.id ?? "0") == "0" ? null : bill;
        });
      },
      width: width,
    );
  }

  String _getFilterName(BuildContext context, TransactionDateFilter filter) {
    switch (filter) {
      case TransactionDateFilter.currentMonth:
        return S.of(context).generalDateRangeCurrentMonth;
      case TransactionDateFilter.last30Days:
        return S.of(context).generalDateRangeLast30Days;
      case TransactionDateFilter.currentYear:
        return S.of(context).generalDateRangeCurrentYear;
      case TransactionDateFilter.lastYear:
        return S.of(context).generalDateRangeLastYear;
      case TransactionDateFilter.all:
        return S.of(context).generalDateRangeAll;
    }
  }
}
