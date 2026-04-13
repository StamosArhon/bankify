import 'dart:convert';

import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/animations.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/extensions.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/home.dart';
import 'package:bankify/pages/home/piggybank/chart.dart';
import 'package:bankify/services/piggy_bank_service.dart';
import 'package:bankify/widgets/input_number.dart';
import 'package:bankify/widgets/materialiconbutton.dart';
import 'package:bankify/widgets/screen_state_view.dart';

class HomePiggybank extends StatefulWidget {
  const HomePiggybank({super.key});

  @override
  State<HomePiggybank> createState() => _HomePiggybankState();
}

class _HomePiggybankState extends State<HomePiggybank>
    with AutomaticKeepAliveClientMixin {
  final Logger log = Logger("Pages.Home.Piggybank");

  final int _numberOfItemsPerRequest = 100;
  PagingState<int, PiggyBankRead> _pagingState =
      PagingState<int, PiggyBankRead>();

  List<AccountStatusData> _accountStatusData = <AccountStatusData>[];
  late final PiggyBankService _piggyBankService;

  @override
  void initState() {
    super.initState();
    _piggyBankService = PiggyBankService(
      api: context.read<FireflyService>().api,
      defaultCurrency: context.read<FireflyService>().defaultCurrency,
    );
    // Add top-right action to open Available Amounts bottom sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PageActions>().set(widget.key!, <Widget>[
        IconButton(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          tooltip: S.of(context).homePiggyAvailableAmounts,
          onPressed: _showAvailableAmountsSheet,
        ),
      ]);
    });
  }

  Future<void> _fetchPage() async {
    if (_pagingState.isLoading) return;

    try {
      final int pageKey = (_pagingState.keys?.last ?? 0) + 1;
      log.finest(
        "Getting page $pageKey (${_pagingState.pages?.length} pages loaded)",
      );

      final PiggyBankPageResult page = await _piggyBankService.fetchPage(
        page: pageKey,
        limit: _numberOfItemsPerRequest,
      );

      if (mounted) {
        setState(() {
          _pagingState = _pagingState.copyWith(
            pages: <List<PiggyBankRead>>[
              ...?_pagingState.pages,
              page.piggyBanks,
            ],
            keys: <int>[...?_pagingState.keys, pageKey],
            hasNextPage: !page.isLastPage,
            isLoading: false,
            error: null,
          );
          _accountStatusData = page.accountStatusData;
        });
      }
    } catch (e, stackTrace) {
      log.severe("_fetchPage()", e, stackTrace);
      if (mounted) {
        setState(() {
          _pagingState = _pagingState.copyWith(error: e, isLoading: false);
        });
      }
    }
  }

  Future<void> _refreshPiggyBanks() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _pagingState = _pagingState.reset();
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.finest(() => "build()");

    int lastGroupId = -1;

    return RefreshIndicator(
      onRefresh: _refreshPiggyBanks,
      child: PagedListView<int, PiggyBankRead>(
        state: _pagingState,
        fetchNextPage: _fetchPage,
        builderDelegate: PagedChildBuilderDelegate<PiggyBankRead>(
          animateTransitions: true,
          transitionDuration: animDurationStandard,
          invisibleItemsThreshold: 10,
          firstPageProgressIndicatorBuilder:
              (BuildContext context) => ScreenStateView.loading(
                title: S.of(context).generalLoading,
                message: S.of(context).homePiggyNoAccountsSubtitle,
              ),
          firstPageErrorIndicatorBuilder:
              (BuildContext context) => ScreenStateView(
                icon: Icons.error_outline,
                title: S.of(context).generalError,
                message: S.of(context).homePiggyNoAccountsSubtitle,
                action: FilledButton(
                  onPressed: _fetchPage,
                  child: Text(S.of(context).generalRetry),
                ),
              ),
          itemBuilder: (BuildContext context, PiggyBankRead piggy, int index) {
            Widget? groupHeader;
            final int groupId =
                (int.tryParse(piggy.attributes.objectGroupId ?? "") ?? 0);
            if (groupId != lastGroupId &&
                groupId != 0 &&
                (piggy.attributes.objectGroupTitle ?? "").isNotEmpty) {
              lastGroupId = groupId;
              groupHeader = Padding(
                padding: const EdgeInsets.only(top: 16, left: 16),
                child: Text(
                  piggy.attributes.objectGroupTitle ?? "(no title)",
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              );
            }
            final double currentAmount =
                double.tryParse(piggy.attributes.currentAmount ?? "") ?? 0;
            final CurrencyRead currency = CurrencyRead(
              id: piggy.attributes.currencyId ?? "0",
              type: "currencies",
              attributes: CurrencyProperties(
                code: piggy.attributes.currencyCode ?? "",
                name: "",
                symbol: piggy.attributes.currencySymbol ?? "",
                decimalPlaces: piggy.attributes.currencyDecimalPlaces,
              ),
            );
            final double targetAmount =
                double.tryParse(piggy.attributes.targetAmount ?? "") ?? 0;
            if (!(piggy.attributes.active ?? false)) {
              return const SizedBox.shrink();
            }
            String subtitle = "";
            if (piggy.attributes.accounts?.isNotEmpty ?? false) {
              if (piggy.attributes.accounts!.length == 1 &&
                  (piggy.attributes.accounts!.first.name?.isNotEmpty ??
                      false)) {
                subtitle = S
                    .of(context)
                    .homePiggyLinked(piggy.attributes.accounts!.first.name!);
              } else if (piggy.attributes.accounts!.length > 1) {
                subtitle = S
                    .of(context)
                    .homePiggyLinked(
                      piggy.attributes.accounts!
                          .map((PiggyBankAccountRead e) => e.name ?? "")
                          .join(", "),
                    );
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                groupHeader ?? const SizedBox.shrink(),
                ListTile(
                  title: Text(piggy.attributes.name),
                  subtitle: Text(subtitle),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  isThreeLine: false,
                  leading: CircleAvatar(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        maxHeight: 40,
                        minWidth: 40,
                        maxWidth: 40,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: <double>[
                            0,
                            (piggy.attributes.percentage ?? 0) / 100,
                            (piggy.attributes.percentage ?? 0) / 100,
                          ],
                          colors: <Color>[
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ],
                        ),
                      ),
                      child: const Icon(Icons.savings_outlined),
                    ),
                  ),
                  trailing: RichText(
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: <InlineSpan>[
                        TextSpan(
                          text: currency.fmt(currentAmount),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium!.copyWith(
                            color:
                                (currentAmount < 0) ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        targetAmount != 0
                            ? const TextSpan(text: "\n")
                            : const TextSpan(),
                        targetAmount != 0
                            ? TextSpan(
                              text: S
                                  .of(context)
                                  .numPercentOf(
                                    (piggy.attributes.percentage ?? 0) / 100,
                                    currency.fmt(targetAmount),
                                  ),
                            )
                            : const TextSpan(),
                      ],
                    ),
                  ),
                  onTap: () async {
                    final bool? shouldRefresh = await Navigator.of(
                      context,
                    ).push<bool>(
                      MaterialPageRoute<bool>(
                        builder:
                            (BuildContext context) =>
                                PiggyDetailsPage(piggy: piggy),
                      ),
                    );
                    if ((shouldRefresh ?? false) && mounted) {
                      await _refreshPiggyBanks();
                    }
                  },
                ),
                piggy.attributes.percentage != null
                    ? LinearProgressIndicator(
                      value: piggy.attributes.percentage! / 100,
                    )
                    : const Divider(height: 0),
              ],
            );
          },
          noItemsFoundIndicatorBuilder:
              (BuildContext context) => ScreenStateView(
                icon: Icons.savings_outlined,
                title: S.of(context).homePiggyNoAccounts,
                message: S.of(context).homePiggyNoAccountsSubtitle,
              ),
        ),
      ),
    );
  }

  void _showAvailableAmountsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // showDragHandle: true,
      builder:
          (BuildContext context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height / 3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(
                      S.of(context).homePiggyAvailableAmounts,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(indent: 8, endIndent: 8),
                  if (_accountStatusData.isEmpty)
                    Flexible(
                      child: Center(
                        child: Text(
                          S.of(context).homePiggyNoAccounts,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _accountStatusData.length,
                        itemBuilder:
                            (BuildContext _, int i) => _accountStatusRow(
                              context,
                              _accountStatusData[i],
                            ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }

  Widget _accountStatusRow(BuildContext context, AccountStatusData statusData) {
    return ListTile(
      title: Text(statusData.account.attributes.name),
      subtitle: Text(
        "Total: ${statusData.currency.fmt(statusData.accountBalance)}",
      ),
      isThreeLine: false,
      trailing: RichText(
        textAlign: TextAlign.end,
        maxLines: 2,
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: <InlineSpan>[
            TextSpan(
              text: statusData.currency.fmt(statusData.availableBalance),
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color:
                    (statusData.availableBalance < 0)
                        ? Colors.red
                        : Colors.green,
                fontWeight: FontWeight.bold,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const TextSpan(text: "\n"),
            TextSpan(
              text: S
                  .of(context)
                  .homePiggyInPiggyBanks(
                    statusData.currency.fmt(statusData.totalInPiggyBanks),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class PiggyDetailsPage extends StatefulWidget {
  const PiggyDetailsPage({super.key, required this.piggy});

  final PiggyBankRead piggy;

  @override
  State<PiggyDetailsPage> createState() => _PiggyDetailsPageState();
}

class _PiggyDetailsPageState extends State<PiggyDetailsPage> {
  final Logger log = Logger("Pages.Home.Piggybank.Details");

  Future<List<PiggyBankEventRead>> _fetchChart() async {
    final FireflyIii api = context.read<FireflyService>().api;

    final Response<PiggyBankEventArray> response = await api
        .v1PiggyBanksIdEventsGet(id: currentPiggy.id);
    apiThrowErrorIfEmpty(response, mounted ? context : null);

    return response.body!.data.sortedBy<DateTime>(
      (PiggyBankEventRead e) =>
          e.attributes.createdAt ?? e.attributes.updatedAt ?? DateTime.now(),
    );
  }

  late PiggyBankRead currentPiggy;
  late Future<List<PiggyBankEventRead>> _chartFuture;
  bool _didMutatePiggy = false;

  @override
  void initState() {
    super.initState();

    currentPiggy = widget.piggy;
    _chartFuture = _fetchChart();
  }

  void _close() {
    Navigator.of(context).pop(_didMutatePiggy);
  }

  Future<void> _adjustBalance() async {
    final PiggyBankSingle? newPiggy = await showDialog<PiggyBankSingle>(
      context: context,
      builder:
          (BuildContext context) => PiggyAdjustBalance(piggy: currentPiggy),
    );
    if (!mounted || newPiggy == null) {
      return;
    }

    setState(() {
      currentPiggy = newPiggy.data;
      _didMutatePiggy = true;
      _chartFuture = _fetchChart();
    });
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");
    final double currentAmount =
        double.tryParse(currentPiggy.attributes.currentAmount ?? "") ?? 0;
    final double targetAmount =
        double.tryParse(currentPiggy.attributes.targetAmount ?? "") ?? 0;
    final double leftAmount =
        double.tryParse(currentPiggy.attributes.leftToSave ?? "") ?? 0;
    final DateTime? startDate = currentPiggy.attributes.startDate?.toLocal();
    final DateTime? targetDate = currentPiggy.attributes.targetDate?.toLocal();
    final CurrencyRead currency = CurrencyRead(
      id: currentPiggy.attributes.currencyId ?? "0",
      type: "currencies",
      attributes: CurrencyProperties(
        code: currentPiggy.attributes.currencyCode ?? "",
        name: "",
        symbol: currentPiggy.attributes.currencySymbol ?? "",
        decimalPlaces: currentPiggy.attributes.currencyDecimalPlaces,
      ),
    );
    final bool hasMultipleAccounts =
        (currentPiggy.attributes.accounts?.length ?? 1) > 1;

    final List<String> infoLines = <String>[];
    if (targetAmount != 0) {
      infoLines.add(S.of(context).homePiggyTarget(currency.fmt(targetAmount)));
    }
    if (!hasMultipleAccounts) {
      infoLines.add(S.of(context).homePiggySaved(currency.fmt(currentAmount)));
    } else {
      infoLines.add(S.of(context).homePiggySavedMultiple);
      for (PiggyBankAccountRead account in currentPiggy.attributes.accounts!) {
        infoLines.add(
          '${account.name}: ${currency.fmt(double.tryParse(account.currentAmount ?? "") ?? 0)}',
        );
      }
    }
    if (leftAmount != 0) {
      infoLines.add(S.of(context).homePiggyRemaining(currency.fmt(leftAmount)));
    }
    if (startDate != null) {
      infoLines.add(S.of(context).homePiggyDateStart(startDate));
    }
    if (targetDate != null) {
      infoLines.add(S.of(context).homePiggyDateTarget(targetDate));
    }

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(currentPiggy.attributes.name),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.price_change_outlined),
              tooltip: S.of(context).homePiggyAdjustDialogTitle,
              onPressed: _adjustBalance,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (currentPiggy.attributes.percentage != null)
                    LinearProgressIndicator(
                      value: currentPiggy.attributes.percentage! / 100,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: infoLines
                          .map(
                            (String line) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(line),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<List<PiggyBankEventRead>>(
                  future: _chartFuture,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<PiggyBankEventRead>> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      log.severe(
                        "error fetching chart",
                        snapshot.error,
                        snapshot.stackTrace,
                      );
                      return SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.savings_outlined, size: 40),
                              const SizedBox(height: 12),
                              Text(S.of(context).errorUnknown),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _chartFuture = _fetchChart();
                                  });
                                },
                                child: Text(S.of(context).generalRetry),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!(snapshot.data?.isNotEmpty ?? false)) {
                      return SizedBox(
                        height: 160,
                        child: Center(
                          child: Text(S.of(context).homeTransactionsEmpty),
                        ),
                      );
                    }

                    return SizedBox(
                      height: 300,
                      width: MediaQuery.of(context).size.width,
                      child: PiggyChart(currentPiggy, snapshot.data!),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PiggyAdjustBalance extends StatefulWidget {
  const PiggyAdjustBalance({super.key, required this.piggy});

  final PiggyBankRead piggy;

  @override
  State<PiggyAdjustBalance> createState() => _PiggyAdjustBalanceState();
}

class _PiggyAdjustBalanceState extends State<PiggyAdjustBalance> {
  final Logger log = Logger("Pages.Home.Piggybank.AdjustBalance");

  final TextEditingController _amountTextController = TextEditingController();
  TransactionTypeProperty _transactionType = TransactionTypeProperty.deposit;

  late double currentAmount;
  late CurrencyRead currency;
  late bool hasMultipleAccounts;
  late List<DropdownMenuEntry<String>> allAccountNames;
  String? selectedAccount;

  @override
  void initState() {
    super.initState();

    currentAmount =
        double.tryParse(widget.piggy.attributes.currentAmount ?? "") ?? 0;
    hasMultipleAccounts = (widget.piggy.attributes.accounts?.length ?? 1) > 1;
    currency = CurrencyRead(
      id: widget.piggy.attributes.currencyId ?? "0",
      type: "currencies",
      attributes: CurrencyProperties(
        code: widget.piggy.attributes.currencyCode ?? "",
        name: "",
        symbol: widget.piggy.attributes.currencySymbol ?? "",
        decimalPlaces: widget.piggy.attributes.currencyDecimalPlaces,
      ),
    );
    allAccountNames = widget.piggy.attributes.accounts!
        .map(
          (PiggyBankAccountRead e) =>
              DropdownMenuEntry<String>(value: e.accountId!, label: e.name!),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _amountTextController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(S.of(context).homePiggyAdjustDialogTitle),
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!hasMultipleAccounts)
                Text(S.of(context).homePiggySaved(currency.fmt(currentAmount))),
              if (hasMultipleAccounts) ...<Widget>[
                Text(S.of(context).homePiggySavedMultiple),
                ...widget.piggy.attributes.accounts!.map(
                  (PiggyBankAccountRead e) => Text(
                    "â€¢ ${e.name}: ${currency.fmt(double.tryParse(e.currentAmount ?? "") ?? 0)}",
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (hasMultipleAccounts) ...<Widget>[
                const SizedBox(height: 16),
                DropdownMenu<String>(
                  dropdownMenuEntries: allAccountNames,
                  label: Text(S.of(context).generalAccount),
                  leadingIcon: const Icon(Icons.account_balance_outlined),
                  onSelected: (String? e) => selectedAccount = e,
                  width: MediaQuery.of(context).size.width - 128 - 24,
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: <Widget>[
                  MaterialIconButton(
                    icon: _transactionType.icon,
                    foregroundColor: Colors.white,
                    backgroundColor: _transactionType.color,
                    onPressed: () {
                      setState(() {
                        if (_transactionType ==
                            TransactionTypeProperty.deposit) {
                          _transactionType = TransactionTypeProperty.withdrawal;
                        } else {
                          _transactionType = TransactionTypeProperty.deposit;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NumberInput(
                      controller: _amountTextController,
                      hintText: "0.00",
                      decimals: currency.attributes.decimalPlaces ?? 2,
                      prefixText: "${currency.attributes.code} ",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 12,
          overflowSpacing: 12,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
            FilledButton(
              onPressed: () async {
                final FireflyIii api = context.read<FireflyService>().api;
                final NavigatorState nav = Navigator.of(context);

                // Amount handling
                double amount =
                    double.tryParse(_amountTextController.text) ?? 0;
                if (amount == 0) {
                  nav.pop();
                }
                if (_transactionType == TransactionTypeProperty.withdrawal) {
                  amount *= -1;
                }

                // Account handling
                if (selectedAccount == null) {
                  nav.pop();
                }
                final List<PiggyBankAccountUpdate> accounts =
                    <PiggyBankAccountUpdate>[];
                if (!hasMultipleAccounts) {
                  final double totalAmount = currentAmount + amount;
                  accounts.add(
                    PiggyBankAccountUpdate(
                      accountId:
                          widget.piggy.attributes.accounts!.first.accountId,
                      currentAmount: totalAmount.toString(),
                    ),
                  );
                  log.finest(
                    () =>
                        "New piggy bank total = $totalAmount out of $currentAmount + $amount",
                  );
                } else {
                  for (PiggyBankAccountRead e
                      in widget.piggy.attributes.accounts!) {
                    accounts.add(
                      PiggyBankAccountUpdate(
                        accountId: e.accountId,
                        currentAmount:
                            selectedAccount == e.accountId
                                ? ((double.tryParse(e.currentAmount ?? "") ??
                                            0) +
                                        amount)
                                    .toString()
                                : e.currentAmount,
                      ),
                    );
                  }
                }

                final Response<PiggyBankSingle> resp = await api
                    .v1PiggyBanksIdPut(
                      id: widget.piggy.id,
                      body: PiggyBankUpdate(accounts: accounts),
                    );
                if (!resp.isSuccessful || resp.body == null) {
                  late String error;
                  try {
                    final ValidationErrorResponse valError =
                        ValidationErrorResponse.fromJson(
                          json.decode(resp.error.toString()),
                        );
                    if (context.mounted) {
                      error = valError.message ?? S.of(context).errorUnknown;
                    } else {
                      error = "[nocontext] Unknown error";
                    }
                  } catch (e) {
                    if (context.mounted) {
                      error = S.of(context).errorUnknown;
                    } else {
                      error = "[nocontext] Unknown error.";
                    }
                  }

                  if (context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder:
                          (BuildContext context) => AlertDialog(
                            icon: const Icon(Icons.error),
                            title: Text(S.of(context).generalError),
                            clipBehavior: Clip.hardEdge,
                            actions: <Widget>[
                              FilledButton(
                                child: Text(S.of(context).generalDismiss),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                            content: Text(error),
                          ),
                    );
                  }
                  return;
                }
                nav.pop(resp.body);
              },
              child: Text(MaterialLocalizations.of(context).saveButtonLabel),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ],
    );
  }
}
