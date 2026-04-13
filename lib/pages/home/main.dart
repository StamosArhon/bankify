import 'dart:async';

import 'package:collection/collection.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/animations.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/extensions.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/home.dart';
import 'package:bankify/pages/home/main/charts/category.dart';
import 'package:bankify/pages/home/main/charts/lastdays.dart';
import 'package:bankify/pages/home/main/charts/netearnings.dart';
import 'package:bankify/pages/home/main/charts/networth.dart';
import 'package:bankify/pages/home/main/charts/summary.dart';
import 'package:bankify/pages/home/main/dashboard.dart';
import 'package:bankify/services/dashboard_service.dart';
import 'package:bankify/settings.dart';
import 'package:bankify/stock.dart';
import 'package:bankify/timezonehandler.dart';
import 'package:bankify/widgets/charts.dart';

class HomeMain extends StatefulWidget {
  const HomeMain({super.key});

  @override
  State<HomeMain> createState() => _HomeMainState();
}

class _HomeMainState extends State<HomeMain>
    with AutomaticKeepAliveClientMixin {
  final Logger log = Logger("Pages.Home.Main");

  final Map<DateTime, double> lastDaysExpense = <DateTime, double>{};
  final Map<DateTime, double> lastDaysIncome = <DateTime, double>{};
  final Map<DateTime, InsightTotalEntry> lastMonthsExpense =
      <DateTime, InsightTotalEntry>{};
  final Map<DateTime, InsightTotalEntry> lastMonthsIncome =
      <DateTime, InsightTotalEntry>{};
  Map<DateTime, double> lastMonthsEarned = <DateTime, double>{};
  Map<DateTime, double> lastMonthsSpent = <DateTime, double>{};
  Map<DateTime, double> lastMonthsAssets = <DateTime, double>{};
  Map<DateTime, double> lastMonthsLiabilities = <DateTime, double>{};
  List<ChartDataSet> overviewChartData = <ChartDataSet>[];
  final List<InsightGroupEntry> catChartData = <InsightGroupEntry>[];
  final List<InsightGroupEntry> tagChartData = <InsightGroupEntry>[];
  final Map<String, BudgetProperties> budgetInfos =
      <String, BudgetProperties>{};
  late TransStock _stock;
  late DashboardService _dashboardService;

  @override
  void initState() {
    super.initState();

    _stock = context.read<FireflyService>().transStock!;
    _dashboardService = DashboardService(
      api: context.read<FireflyService>().api,
      tzHandler: context.read<FireflyService>().tzHandler,
      defaultCurrency: context.read<FireflyService>().defaultCurrency,
    );
    _stock.addListener(_refreshStats);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PageActions>().set(widget.key!, <Widget>[
        IconButton(
          icon: const Icon(Icons.dashboard_customize_outlined),
          tooltip: S.of(context).homeMainDialogSettingsTitle,
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<Widget>(
                builder:
                    (BuildContext context) => const DashboardSettingsPage(),
              ),
            );
          },
        ),
      ]);
    });
  }

  @override
  void dispose() {
    _stock.removeListener(_refreshStats);

    super.dispose();
  }

  Future<bool> _fetchLastDays() async {
    if (lastDaysExpense.isNotEmpty && lastDaysIncome.isNotEmpty) {
      return true;
    }

    final DashboardLastDaysData data = await _dashboardService.fetchLastDays();
    lastDaysExpense.addAll(data.expense);
    lastDaysIncome.addAll(data.income);

    return true;
  }

  Future<bool> _fetchOverviewChart() async {
    if (overviewChartData.isNotEmpty) {
      return true;
    }

    overviewChartData = await _dashboardService.fetchOverviewChart();

    return true;
  }

  Future<bool> _fetchLastMonths() async {
    if (lastMonthsExpense.isNotEmpty && lastMonthsIncome.isNotEmpty) {
      return true;
    }

    final DashboardLastMonthsData data =
        await _dashboardService.fetchLastMonthsSummary();
    lastMonthsExpense.addAll(data.expense);
    lastMonthsIncome.addAll(data.income);

    return true;
  }

  Future<bool> _fetchCategories({bool tags = false}) async {
    if ((tags && tagChartData.isNotEmpty) ||
        (!tags && catChartData.isNotEmpty)) {
      return true;
    }

    final List<InsightGroupEntry> data = await _dashboardService
        .fetchCategoryInsights(tags: tags);
    if (tags) {
      tagChartData.addAll(data);
    } else {
      catChartData.addAll(data);
    }

    return true;
  }

  Future<List<BudgetLimitRead>> _fetchBudgets() async {
    final DashboardBudgetData data = await _dashboardService.fetchBudgetData();
    budgetInfos
      ..clear()
      ..addAll(data.budgetInfos);
    return data.budgetLimits;
  }

  Future<List<BillRead>> _fetchBills() {
    return _dashboardService.fetchUpcomingBills();
  }

  Future<bool> _fetchBalance() async {
    if (lastMonthsEarned.isNotEmpty) {
      return true;
    }

    final DashboardBalanceData data =
        await _dashboardService.fetchBalanceData();
    lastMonthsEarned = data.earned;
    lastMonthsSpent = data.spent;
    lastMonthsAssets = data.assets;
    lastMonthsLiabilities = data.liabilities;

    return true;
  }

  Future<void> _refreshStats() async {
    setState(() {
      lastDaysExpense.clear();
      lastDaysIncome.clear();
      overviewChartData.clear();
      lastMonthsExpense.clear();
      lastMonthsIncome.clear();
      tagChartData.clear();
      catChartData.clear();
      lastMonthsEarned.clear();
      lastMonthsSpent.clear();
      lastMonthsAssets.clear();
      lastMonthsLiabilities.clear();
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.finest(() => "build()");

    final CurrencyRead defaultCurrency =
        context.read<FireflyService>().defaultCurrency;

    final List<DashboardCards> cards = List<DashboardCards>.from(
      context.watch<SettingsProvider>().dashboardOrder,
    );

    final List<DashboardCards> hidden =
        context.watch<SettingsProvider>().dashboardHidden;
    for (DashboardCards e in hidden) {
      cards.remove(e);
    }

    return RefreshIndicator(
      onRefresh: _refreshStats,
      child: ListView(
        cacheExtent: 1000,
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          for (int i = 0; i < cards.length; i++)
            switch (cards[i]) {
              DashboardCards.dailyavg => ChartCard(
                title: S.of(context).homeMainChartDailyTitle,
                future: _fetchLastDays(),
                summary: () {
                  double sevenDayTotal = 0;
                  lastDaysExpense.forEach(
                    (DateTime _, double e) => sevenDayTotal -= e.abs(),
                  );
                  lastDaysIncome.forEach(
                    (DateTime _, double e) => sevenDayTotal += e.abs(),
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(S.of(context).homeMainChartDailyAvg),
                      Text(
                        defaultCurrency.fmt(sevenDayTotal / 7),
                        style: TextStyle(
                          color: sevenDayTotal < 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                height: 125,
                child:
                    () => LastDaysChart(
                      expenses: lastDaysExpense,
                      incomes: lastDaysIncome,
                    ),
              ),
              DashboardCards.categories => ChartCard(
                title: S.of(context).homeMainChartCategoriesTitle,
                future: _fetchCategories(),
                height: 175,
                child: () => CategoryChart(data: catChartData),
              ),
              DashboardCards.tags => ChartCard(
                title: S.of(context).homeMainChartTagsTitle,
                future: _fetchCategories(tags: true),
                height: 175,
                child: () => CategoryChart(data: tagChartData),
              ),
              DashboardCards.accounts => ChartCard(
                title: S.of(context).homeMainChartAccountsTitle,
                future: _fetchOverviewChart(),
                summary:
                    () => Table(
                      //border: TableBorder.all(), // :DEBUG:
                      columnWidths: const <int, TableColumnWidth>{
                        0: FixedColumnWidth(24),
                        1: FlexColumnWidth(),
                        2: IntrinsicColumnWidth(),
                      },
                      children: <TableRow>[
                        TableRow(
                          children: <Widget>[
                            const SizedBox.shrink(),
                            Text(
                              S.of(context).generalAccount,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                S.of(context).generalBalance,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                        ...overviewChartData.mapIndexed((
                          int i,
                          ChartDataSet e,
                        ) {
                          final Map<String, dynamic> entries =
                              e.entries as Map<String, dynamic>;
                          final double balance =
                              double.tryParse(entries.entries.last.value) ?? 0;
                          final CurrencyRead currency = CurrencyRead(
                            id: e.currencyId ?? "0",
                            type: "currencies",
                            attributes: CurrencyProperties(
                              code: e.currencyCode ?? "",
                              name: "",
                              symbol: e.currencySymbol ?? "",
                              decimalPlaces: e.currencyDecimalPlaces,
                            ),
                          );
                          return TableRow(
                            children: <Widget>[
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  "⬤",
                                  style: TextStyle(
                                    color: charts.ColorUtil.toDartColor(
                                      possibleChartColors[i %
                                          possibleChartColors.length],
                                    ),
                                    textBaseline: TextBaseline.ideographic,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              Text(e.label!),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  currency.fmt(balance),
                                  style: TextStyle(
                                    color:
                                        (balance < 0)
                                            ? Colors.red
                                            : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                height: 175,
                onTap:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (BuildContext context) => const SummaryChartPopup(),
                    ),
                child: () => SummaryChart(data: overviewChartData),
              ),
              DashboardCards.netearnings => ChartCard(
                title: S.of(context).homeMainChartNetEarningsTitle,
                future: _fetchLastMonths(),
                summary:
                    () => Table(
                      // border: TableBorder.all(), // :DEBUG:
                      columnWidths: const <int, TableColumnWidth>{
                        0: FixedColumnWidth(24),
                        1: IntrinsicColumnWidth(),
                        2: FlexColumnWidth(),
                        3: FlexColumnWidth(),
                        4: FlexColumnWidth(),
                      },
                      children: <TableRow>[
                        TableRow(
                          children: <Widget>[
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            ...lastMonthsIncome.keys.toList().reversed.map(
                              (DateTime e) => Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  DateFormat(DateFormat.MONTH).format(e),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: <Widget>[
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                "⬤",
                                style: TextStyle(
                                  color: Colors.green,
                                  textBaseline: TextBaseline.ideographic,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Text(S.of(context).generalIncome),
                            ...lastMonthsIncome.entries.toList().reversed.map(
                              (MapEntry<DateTime, InsightTotalEntry> e) =>
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      defaultCurrency.fmt(
                                        e.value.differenceFloat ?? 0,
                                      ),
                                      style: const TextStyle(
                                        fontFeatures: <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: <Widget>[
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                "⬤",
                                style: TextStyle(
                                  color: Colors.red,
                                  textBaseline: TextBaseline.ideographic,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Text(S.of(context).generalExpenses),
                            ...lastMonthsExpense.entries.toList().reversed.map(
                              (MapEntry<DateTime, InsightTotalEntry> e) =>
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      defaultCurrency.fmt(
                                        e.value.differenceFloat ?? 0,
                                      ),
                                      style: const TextStyle(
                                        fontFeatures: <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: <Widget>[
                            const SizedBox.shrink(),
                            Text(
                              S.of(context).generalSum,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...lastMonthsIncome.entries.toList().reversed.map((
                              MapEntry<DateTime, InsightTotalEntry> e,
                            ) {
                              final double income =
                                  e.value.differenceFloat ?? 0;
                              double expense = 0;
                              if (lastMonthsExpense.containsKey(e.key)) {
                                expense =
                                    lastMonthsExpense[e.key]!.differenceFloat ??
                                    0;
                              }
                              final double sum = income + expense;
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  defaultCurrency.fmt(sum),
                                  style: TextStyle(
                                    color:
                                        (sum < 0) ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                onTap:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (BuildContext context) =>
                              const NetEarningsChartPopup(),
                    ),
                child:
                    () => NetEarningsChart(
                      expenses: lastMonthsExpense,
                      income: lastMonthsIncome,
                    ),
              ),
              DashboardCards.networth => ChartCard(
                title: S.of(context).homeMainChartNetWorthTitle,
                future: _fetchBalance(),
                summary:
                    () => Table(
                      //border: TableBorder.all(), // :DEBUG:
                      columnWidths: const <int, TableColumnWidth>{
                        0: FixedColumnWidth(24),
                        1: IntrinsicColumnWidth(),
                        2: FlexColumnWidth(),
                        3: FlexColumnWidth(),
                        4: FlexColumnWidth(),
                      },
                      children: <TableRow>[
                        TableRow(
                          children: <Widget>[
                            const SizedBox.shrink(),
                            const SizedBox.shrink(),
                            ...lastMonthsAssets.keys
                                .toList()
                                .reversed
                                .take(3)
                                .toList()
                                .reversed
                                .map(
                                  (DateTime e) => Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      DateFormat(DateFormat.MONTH).format(e),
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        TableRow(
                          children: <Widget>[
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                "⬤",
                                style: TextStyle(
                                  color: Colors.green,
                                  textBaseline: TextBaseline.ideographic,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Text(S.of(context).generalAssets),
                            ...lastMonthsAssets.entries
                                .toList()
                                .reversed
                                .take(3)
                                .toList()
                                .reversed
                                .map(
                                  (MapEntry<DateTime, double> e) => Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      defaultCurrency.fmt(e.value),
                                      style: const TextStyle(
                                        fontFeatures: <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        TableRow(
                          children: <Widget>[
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                "⬤",
                                style: TextStyle(
                                  color: Colors.red,
                                  textBaseline: TextBaseline.ideographic,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Text(S.of(context).generalLiabilities),
                            ...lastMonthsLiabilities.entries
                                .toList()
                                .reversed
                                .take(3)
                                .toList()
                                .reversed
                                .map(
                                  (MapEntry<DateTime, double> e) => Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      defaultCurrency.fmt(e.value),
                                      style: const TextStyle(
                                        fontFeatures: <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        TableRow(
                          children: <Widget>[
                            const SizedBox.shrink(),
                            Text(
                              S.of(context).generalSum,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...lastMonthsAssets.entries
                                .toList()
                                .reversed
                                .take(3)
                                .toList()
                                .reversed
                                .map((MapEntry<DateTime, double> e) {
                                  final double assets = e.value;
                                  final double liabilities =
                                      lastMonthsLiabilities[e.key] ?? 0;
                                  final double sum = assets + liabilities;
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      defaultCurrency.fmt(sum),
                                      style: TextStyle(
                                        color:
                                            (sum < 0)
                                                ? Colors.red
                                                : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: const <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                          ],
                        ),
                      ],
                    ),
                child:
                    () => NetWorthChart(
                      assets: lastMonthsAssets,
                      liabilities: lastMonthsLiabilities,
                    ),
              ),
              DashboardCards.budgets => AnimatedHeight(
                child: FutureBuilder<List<BudgetLimitRead>>(
                  future: _fetchBudgets(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<BudgetLimitRead>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      if (snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Card(
                        clipBehavior: Clip.hardEdge,
                        margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                S.of(context).homeMainBudgetTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            BudgetList(
                              budgetInfos: budgetInfos,
                              snapshot: snapshot,
                            ),
                          ],
                        ),
                      );
                    } else if (snapshot.hasError) {
                      log.severe(
                        "error fetching budgets",
                        snapshot.error,
                        snapshot.stackTrace,
                      );
                      return Text(snapshot.error!.toString());
                    } else {
                      return const Card(
                        clipBehavior: Clip.hardEdge,
                        margin: EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                  },
                ),
              ),
              DashboardCards.bills => AnimatedHeight(
                child: FutureBuilder<List<BillRead>>(
                  future: _fetchBills(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<BillRead>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      if (snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Card(
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                S.of(context).homeMainBillsTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            BillList(snapshot: snapshot),
                          ],
                        ),
                      );
                    } else if (snapshot.hasError) {
                      log.severe(
                        "error fetching bills",
                        snapshot.error,
                        snapshot.stackTrace,
                      );
                      return Text(snapshot.error!.toString());
                    } else {
                      return const Card(
                        clipBehavior: Clip.hardEdge,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                  },
                ),
              ),
            },
          const SizedBox(height: 68),
        ],
      ),
    );
  }
}

class BudgetList extends StatelessWidget {
  const BudgetList({
    super.key,
    required this.budgetInfos,
    required this.snapshot,
  });

  final Map<String, BudgetProperties> budgetInfos;
  final AsyncSnapshot<List<BudgetLimitRead>> snapshot;

  @override
  Widget build(BuildContext context) {
    final TimeZoneHandler tzHandler = context.read<FireflyService>().tzHandler;

    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final List<Widget> widgets = <Widget>[];
            final int tsNow = tzHandler.sNow().millisecondsSinceEpoch;

            for (BudgetLimitRead budget in snapshot.data!) {
              final List<Widget> stackWidgets = <Widget>[];
              late double spent;
              if (budget.attributes.spent?.isNotEmpty ?? false) {
                spent =
                    (double.tryParse(
                              budget.attributes.spent!.first.sum ?? "",
                            ) ??
                            0)
                        .abs();
              } else {
                spent = 0;
              }
              final double available =
                  double.tryParse(budget.attributes.amount ?? "") ?? 0;

              final int tsStart =
                  tzHandler
                      .sTime(budget.attributes.start!)
                      .millisecondsSinceEpoch;
              final int tsEnd =
                  tzHandler
                      .sTime(budget.attributes.end!)
                      .millisecondsSinceEpoch;
              late double passedDays;
              if (tsEnd == tsStart) {
                passedDays = 2; // Hides the bar
              } else {
                passedDays = (tsNow - tsStart) / (tsEnd - tsStart);
                if (passedDays > 1) {
                  passedDays = 2; // Hides the bar
                }
              }

              final BudgetProperties? budgetInfo =
                  budgetInfos[budget.attributes.budgetId];
              if (budgetInfo == null || available == 0) {
                continue;
              }
              final CurrencyRead currency = CurrencyRead(
                id: budget.attributes.currencyId ?? "0",
                type: "currencies",
                attributes: CurrencyProperties(
                  code: budget.attributes.currencyCode ?? "",
                  name: budget.attributes.currencyName ?? "",
                  symbol: budget.attributes.currencySymbol ?? "",
                  decimalPlaces: budget.attributes.currencyDecimalPlaces,
                ),
              );
              Color lineColor = Colors.green;
              Color? bgColor;
              double value = spent / available;
              if (spent > available) {
                lineColor = Colors.red;
                bgColor = Colors.green;
                value = value % 1;
              }

              if (widgets.isNotEmpty) {
                widgets.add(const SizedBox(height: 8));
              }
              widgets.add(
                RichText(
                  text: TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: budgetInfo.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextSpan(
                        text:
                            budget.attributes.period?.isNotEmpty ?? false
                                ? S
                                    .of(context)
                                    .homeMainBudgetInterval(
                                      tzHandler
                                          .sTime(budget.attributes.start!)
                                          .toLocal(),
                                      tzHandler
                                          .sTime(budget.attributes.end!)
                                          .toLocal(),
                                      budget.attributes.period!,
                                    )
                                : S
                                    .of(context)
                                    .homeMainBudgetIntervalSingle(
                                      tzHandler
                                          .sTime(budget.attributes.start!)
                                          .toLocal(),
                                      tzHandler
                                          .sTime(budget.attributes.end!)
                                          .toLocal(),
                                    ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
              stackWidgets.add(
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      S.of(context).numPercent(spent / available),
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge!.copyWith(color: lineColor),
                    ),
                    Text(
                      S
                          .of(context)
                          .homeMainBudgetSum(
                            currency.fmt(
                              (available - spent).abs(),
                              decimalDigits: 0,
                            ),
                            (spent > available) ? "over" : "leftfrom",
                            currency.fmt(available, decimalDigits: 0),
                          ),
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge!.copyWith(color: lineColor),
                    ),
                  ],
                ),
              );
              stackWidgets.add(
                Positioned.fill(
                  top: 20, // Height of Row() with text
                  bottom: 4,
                  child: LinearProgressIndicator(
                    color: lineColor,
                    backgroundColor: bgColor,
                    value: value,
                  ),
                ),
              );
              widgets.add(
                LayoutBuilder(
                  builder:
                      (BuildContext context, BoxConstraints constraints) =>
                          Stack(
                            children: <Widget>[
                              // Row + ProgressIndicator + Bottom Padding
                              const SizedBox(height: 20 + 4 + 4),
                              ...stackWidgets,
                              Positioned(
                                left: constraints.biggest.width * passedDays,
                                top: 16,
                                bottom: 0,
                                width: 3,
                                child: Container(
                                  color:
                                      (spent / available > passedDays)
                                          ? Colors.redAccent
                                          : Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widgets,
            );
          },
        ),
      ),
    );
  }
}

class BillList extends StatelessWidget {
  const BillList({super.key, required this.snapshot});

  final AsyncSnapshot<List<BillRead>> snapshot;

  @override
  Widget build(BuildContext context) {
    final TimeZoneHandler tzHandler = context.read<FireflyService>().tzHandler;

    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final List<Widget> widgets = <Widget>[];
            snapshot.data!.sort((BillRead a, BillRead b) {
              final int dateCompare = (a.attributes.nextExpectedMatch ??
                      tzHandler.sNow())
                  .compareTo(
                    b.attributes.nextExpectedMatch ?? tzHandler.sNow(),
                  );
              if (dateCompare != 0) {
                return dateCompare;
              }
              final int orderCompare = (a.attributes.order ?? 0).compareTo(
                b.attributes.order ?? 0,
              );
              if (orderCompare != 0) {
                return orderCompare;
              }
              return a.attributes.avgAmount().compareTo(
                b.attributes.avgAmount(),
              );
            });

            DateTime lastDate = (snapshot
                        .data!
                        .first
                        .attributes
                        .nextExpectedMatch ??
                    tzHandler.sNow())
                .subtract(const Duration(days: 1));
            for (BillRead bill in snapshot.data!) {
              if (!(bill.attributes.active ?? false)) {
                continue;
              }

              final DateTime nextMatch =
                  bill.attributes.nextExpectedMatch != null
                      ? tzHandler
                          .sTime(bill.attributes.nextExpectedMatch!)
                          .toLocal()
                      : tzHandler.sNow();
              final CurrencyRead currency = CurrencyRead(
                id: bill.attributes.currencyId ?? "0",
                type: "currencies",
                attributes: CurrencyProperties(
                  code: bill.attributes.currencyCode ?? "",
                  name: "",
                  symbol: bill.attributes.currencySymbol ?? "",
                  decimalPlaces: bill.attributes.currencyDecimalPlaces,
                ),
              );

              if (nextMatch != lastDate) {
                if (widgets.isNotEmpty) {
                  widgets.add(const SizedBox(height: 8));
                }
                widgets.add(
                  Text(
                    DateFormat.yMd().format(nextMatch),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
                lastDate = nextMatch;
              }
              widgets.add(
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text:
                                bill.attributes.name!.length > 30
                                    ? bill.attributes.name!.replaceRange(
                                      30,
                                      bill.attributes.name!.length,
                                      "…",
                                    )
                                    : bill.attributes.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          TextSpan(
                            text: S
                                .of(context)
                                .homeMainBillsInterval(
                                  bill.attributes.repeatFreq!.value ?? "",
                                ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currency.fmt(bill.attributes.avgAmount()),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widgets,
            );
          },
        ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    required this.future,
    this.height = 150,
    this.summary,
    this.onTap,
  });

  final String title;
  final Widget Function() child;
  final Future<bool> future;
  final Widget Function()? summary;
  final double height;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final Logger log = Logger("Pages.Home.Main.ChartCard");
    final List<Widget> summaryWidgets = <Widget>[];

    return AnimatedHeight(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          clipBehavior: Clip.hardEdge,
          child: FutureBuilder<bool>(
            future: future,
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                if (summary != null) {
                  summaryWidgets.add(const Divider(indent: 16, endIndent: 16));
                  summaryWidgets.add(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: summary!(),
                    ),
                  );
                }
                return InkWell(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            onTap != null
                                ? Icon(
                                  Icons.touch_app_outlined,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                )
                                : const SizedBox.shrink(),
                          ],
                        ),
                      ),
                      Ink(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        ),
                        child: SizedBox(
                          height: height,
                          child:
                              onTap != null
                                  // AbsorbPointer fixes SfChart invalidating the onTap feedback
                                  ? AbsorbPointer(child: child())
                                  : child(),
                        ),
                      ),
                      ...summaryWidgets,
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                log.severe(
                  "error getting chart card data",
                  snapshot.error,
                  snapshot.stackTrace,
                );
                return Text(snapshot.error!.toString());
              } else {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
