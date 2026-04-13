import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/animations.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/extensions.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/bills/billchart.dart';
import 'package:bankify/pages/transaction.dart';
import 'package:bankify/timezonehandler.dart';
import 'package:bankify/widgets/screen_state_view.dart';

class BillDetails extends StatefulWidget {
  const BillDetails({super.key, required this.bill});

  final BillRead bill;

  @override
  State<BillDetails> createState() => _BillDetailsState();
}

class _BillDetailsState extends State<BillDetails> {
  final Logger log = Logger("Pages.Bills.Details");
  PagingState<int, TransactionRead> _pagingState =
      PagingState<int, TransactionRead>();
  final GlobalKey<BillChartState> _billChartKey = GlobalKey<BillChartState>();
  String? _openingTransactionId;

  late final CurrencyRead _currency;
  late final TimeZoneHandler _tzHandler;

  @override
  void initState() {
    log.finest(() => "initState()");

    super.initState();

    _currency = CurrencyRead(
      id: "0",
      type: "currencies",
      attributes: CurrencyProperties(
        code: widget.bill.attributes.currencyCode ?? "",
        name: "",
        symbol: widget.bill.attributes.currencySymbol ?? "",
        decimalPlaces: widget.bill.attributes.currencyDecimalPlaces,
      ),
    );
    _tzHandler = context.read<FireflyService>().tzHandler;
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bill.attributes.name!),
        elevation: 1,
        scrolledUnderElevation: 1,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: <Widget>[
          AnimatedHeight(
            child: Card(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.info_outline),
                    ),
                    title:
                        widget.bill.attributes.amountMax ==
                                widget.bill.attributes.amountMin
                            ? Text(
                              S
                                  .of(context)
                                  .billsExactAmountAndFrequency(
                                    _currency.fmt(
                                      double.tryParse(
                                            widget.bill.attributes.amountMin ??
                                                "0",
                                          ) ??
                                          0,
                                    ),
                                    widget.bill.attributes.repeatFreq
                                        .toString(),
                                    widget.bill.attributes.skip ?? 0,
                                  ),
                            )
                            : Text(
                              S
                                  .of(context)
                                  .billsAmountAndFrequency(
                                    _currency.fmt(
                                      double.tryParse(
                                            widget.bill.attributes.amountMin ??
                                                "0",
                                          ) ??
                                          0,
                                    ),
                                    _currency.fmt(
                                      double.tryParse(
                                            widget.bill.attributes.amountMax ??
                                                "0",
                                          ) ??
                                          0,
                                    ),
                                    widget.bill.attributes.repeatFreq
                                        .toString(),
                                    widget.bill.attributes.skip ?? 0,
                                  ),
                            ),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        widget.bill.attributes.active ?? false
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                      ),
                    ),
                    title: Text(
                      widget.bill.attributes.active ?? false
                          ? S.of(context).billsIsActive
                          : S.of(context).billsNotActive,
                    ),
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.calendar_month),
                    ),
                    title: Text(S.of(context).billsNextExpectedMatch),
                    trailing: Text(
                      DateFormat.yMMMMd().format(
                        _tzHandler
                            .sTime(widget.bill.attributes.payDates![0])
                            .toLocal(),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BillChart(key: _billChartKey, billId: widget.bill.id),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            /*child: RawScrollbar(
              radius: const Radius.circular(12),
              thickness: 5,
              thumbVisibility: true,
              thumbColor: Theme.of(context).colorScheme.outlineVariant,
              crossAxisMargin: 4,
              mainAxisMargin: 4,*/
            child: PagedListView<int, TransactionRead>(
              state: _pagingState,
              fetchNextPage: _fetchPage,
              physics: const ClampingScrollPhysics(),
              builderDelegate: PagedChildBuilderDelegate<TransactionRead>(
                animateTransitions: true,
                transitionDuration: animDurationStandard,
                invisibleItemsThreshold: 20,
                itemBuilder: _transactionRowBuilder,
                firstPageProgressIndicatorBuilder:
                    (BuildContext context) => ScreenStateView.loading(
                      title: S.of(context).generalLoading,
                    ),
                firstPageErrorIndicatorBuilder:
                    (BuildContext context) => ScreenStateView(
                      icon: Icons.receipt_long_outlined,
                      title: S.of(context).errorUnknown,
                      message: S.of(context).billsListEmpty,
                      action: FilledButton(
                        onPressed: _fetchPage,
                        child: Text(S.of(context).generalRetry),
                      ),
                    ),
                noItemsFoundIndicatorBuilder: _emptyListBuilder,
              ),
            ),
            //),
          ),
        ],
      ),
    );
  }

  Widget _transactionRowBuilder(
    BuildContext context,
    TransactionRead transaction,
    int index,
  ) {
    final DateTime date =
        _tzHandler
            .sTime(transaction.attributes.transactions.first.date)
            .toLocal();
    final bool isOpening = _openingTransactionId == transaction.id;

    return ListTile(
      title: Text.rich(_getTransactionTitle(transaction)),
      subtitle: Text(
        DateFormat.yMMMMd().format(date),
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      isThreeLine: false,
      trailing:
          isOpening
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
              : RichText(
                textAlign: TextAlign.end,
                maxLines: 2,
                text: TextSpan(
                  text: _getTransactionAmount(transaction),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.red,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                  children: <InlineSpan>[
                    const TextSpan(text: "\n"),
                    TextSpan(
                      text: _getTransactionSource(transaction),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
      onTap: isOpening ? null : () => _openTransaction(transaction),
    );
  }

  TextSpan _getTransactionTitle(TransactionRead transaction) {
    if (transaction.attributes.groupTitle != null) {
      return TextSpan(
        text: transaction.attributes.groupTitle,
        children: <InlineSpan>[
          TextSpan(
            text: " (${S.of(context).generalMultiple})",
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      );
    }

    return TextSpan(
      text: transaction.attributes.transactions.first.description,
    );
  }

  String _getTransactionAmount(TransactionRead transaction) {
    double amount = 0;
    for (TransactionSplit split in transaction.attributes.transactions) {
      if (split.billId == widget.bill.id) {
        amount += double.tryParse(split.amount) ?? 0;
      }
    }

    return _currency.fmt(amount);
  }

  String _getTransactionSource(TransactionRead transaction) {
    for (TransactionSplit split in transaction.attributes.transactions) {
      if (split.billId == widget.bill.id) {
        return split.sourceName!;
      }
    }
    return "";
  }

  Widget _emptyListBuilder(BuildContext context) {
    return ScreenStateView(
      icon: Icons.receipt_long_outlined,
      title: S.of(context).billsNoTransactions,
      message: S.of(context).billsListEmpty,
    );
  }

  Future<void> _openTransaction(TransactionRead transaction) async {
    setState(() {
      _openingTransactionId = transaction.id;
    });

    try {
      final TransactionRead fullTransaction = await _fetchFullTx(
        transaction.id,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<Widget>(
          builder:
              (BuildContext context) =>
                  TransactionPage(transaction: fullTransaction),
        ),
      );
    } catch (e, stackTrace) {
      log.severe('open transaction from bill details', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).errorUnknown),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingTransactionId = null;
        });
      }
    }
  }

  Future<void> _fetchPage() async {
    if (_pagingState.isLoading) return;

    try {
      final FireflyIii api = context.read<FireflyService>().api;

      final int pageKey = (_pagingState.keys?.last ?? 0) + 1;
      log.finest(
        "Getting page $pageKey (${_pagingState.pages?.length} items loaded so far)",
      );

      final Response<TransactionArray> response = await api
          .v1BillsIdTransactionsGet(id: widget.bill.id, page: pageKey);
      apiThrowErrorIfEmpty(response, mounted ? context : null);

      _billChartKey.currentState!.doneLoading();
      final List<TransactionRead> transactions = response.body!.data;
      _billChartKey.currentState!.addTransactions(transactions);

      final bool isLastPage =
          (response.body!.meta.pagination?.currentPage ?? 1) ==
          (response.body!.meta.pagination?.totalPages ?? 1);

      if (mounted) {
        setState(() {
          _pagingState = _pagingState.copyWith(
            pages: <List<TransactionRead>>[
              ...?_pagingState.pages,
              transactions,
            ],
            keys: <int>[...?_pagingState.keys, pageKey],
            hasNextPage: !isLastPage,
            isLoading: false,
            error: null,
          );
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

  Future<TransactionRead> _fetchFullTx(String id) async {
    final FireflyIii api = context.read<FireflyService>().api;

    final Response<TransactionSingle> response = await api.v1TransactionsIdGet(
      id: id,
    );
    apiThrowErrorIfEmpty(response, mounted ? context : null);

    return response.body!.data;
  }
}
