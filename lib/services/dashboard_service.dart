import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/extensions.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/timezonehandler.dart';

class DashboardLastDaysData {
  const DashboardLastDaysData({required this.expense, required this.income});

  final Map<DateTime, double> expense;
  final Map<DateTime, double> income;
}

class DashboardLastMonthsData {
  const DashboardLastMonthsData({required this.expense, required this.income});

  final Map<DateTime, InsightTotalEntry> expense;
  final Map<DateTime, InsightTotalEntry> income;
}

class DashboardBudgetData {
  const DashboardBudgetData({
    required this.budgetInfos,
    required this.budgetLimits,
  });

  final Map<String, BudgetProperties> budgetInfos;
  final List<BudgetLimitRead> budgetLimits;
}

class DashboardBalanceData {
  const DashboardBalanceData({
    required this.earned,
    required this.spent,
    required this.assets,
    required this.liabilities,
  });

  final Map<DateTime, double> earned;
  final Map<DateTime, double> spent;
  final Map<DateTime, double> assets;
  final Map<DateTime, double> liabilities;
}

class DashboardService {
  const DashboardService({
    required this.api,
    required this.tzHandler,
    required this.defaultCurrency,
  });

  final FireflyIii api;
  final TimeZoneHandler tzHandler;
  final CurrencyRead defaultCurrency;

  Future<DashboardLastDaysData> fetchLastDays() async {
    final Map<DateTime, double> lastDaysExpense = <DateTime, double>{};
    final Map<DateTime, double> lastDaysIncome = <DateTime, double>{};
    final TZDateTime now = tzHandler.sNow().setTimeOfDay(
      const TimeOfDay(hour: 12, minute: 0),
    );

    final Response<List<ChartDataSet>> response = await api
        .v1ChartBalanceBalanceGet(
          start: DateFormat(
            'yyyy-MM-dd',
            'en_US',
          ).format(now.copyWith(day: now.day - 6)),
          end: DateFormat('yyyy-MM-dd', 'en_US').format(now),
          period: V1ChartBalanceBalanceGetPeriod.value_1d,
        );
    apiThrowErrorIfEmpty(response, null);

    for (final ChartDataSet entry in response.body!) {
      final Map<String, dynamic> entries =
          entry.entries as Map<String, dynamic>;
      entries.forEach((String dateStr, dynamic valueStr) {
        final DateTime date = tzHandler
            .sTime(DateTime.parse(dateStr))
            .toLocal()
            .setTimeOfDay(const TimeOfDay(hour: 12, minute: 0));

        final double value = double.tryParse(valueStr) ?? 0;
        if (entry.label == "earned") {
          lastDaysIncome[date] = (lastDaysIncome[date] ?? 0) + value;
        } else if (entry.label == "spent") {
          lastDaysExpense[date] = (lastDaysExpense[date] ?? 0) + value;
        }
      });
    }

    return DashboardLastDaysData(
      expense: lastDaysExpense,
      income: lastDaysIncome,
    );
  }

  Future<List<ChartDataSet>> fetchOverviewChart() async {
    final DateTime now = tzHandler.sNow().clearTime();
    final Response<ChartLine> response = await api.v1ChartAccountOverviewGet(
      start: DateFormat(
        'yyyy-MM-dd',
        'en_US',
      ).format(now.copyWith(month: now.month - 3)),
      end: DateFormat('yyyy-MM-dd', 'en_US').format(now),
      period: V1ChartAccountOverviewGetPeriod.value_1d,
    );
    apiThrowErrorIfEmpty(response, null);
    return response.body!;
  }

  Future<DashboardLastMonthsData> fetchLastMonthsSummary() async {
    final Map<DateTime, InsightTotalEntry> expense =
        <DateTime, InsightTotalEntry>{};
    final Map<DateTime, InsightTotalEntry> income =
        <DateTime, InsightTotalEntry>{};
    final DateTime now = tzHandler.sNow().clearTime();
    final List<DateTime> lastMonths = <DateTime>[];
    for (int i = 0; i < 3; i++) {
      lastMonths.add(DateTime(now.year, now.month - i, (i == 0) ? now.day : 1));
    }

    for (final DateTime month in lastMonths) {
      late DateTime start;
      late DateTime end;
      if (month == lastMonths.first) {
        start = month.copyWith(day: 1);
        end = month;
      } else {
        start = month;
        end = month.copyWith(month: month.month + 1, day: 0);
      }

      final (
        Response<InsightTotal> expenseResponse,
        Response<InsightTotal> incomeResponse,
      ) = await (
            api.v1InsightExpenseTotalGet(
              start: DateFormat('yyyy-MM-dd', 'en_US').format(start),
              end: DateFormat('yyyy-MM-dd', 'en_US').format(end),
            ),
            api.v1InsightIncomeTotalGet(
              start: DateFormat('yyyy-MM-dd', 'en_US').format(start),
              end: DateFormat('yyyy-MM-dd', 'en_US').format(end),
            ),
          ).wait;
      apiThrowErrorIfEmpty(expenseResponse, null);
      apiThrowErrorIfEmpty(incomeResponse, null);

      expense[month] =
          expenseResponse.body!.isNotEmpty
              ? expenseResponse.body!.first
              : const InsightTotalEntry(differenceFloat: 0);
      income[month] =
          incomeResponse.body!.isNotEmpty
              ? incomeResponse.body!.first
              : const InsightTotalEntry(differenceFloat: 0);
    }

    double maxNum = 0;
    income.forEach((_, InsightTotalEntry value) {
      if ((value.differenceFloat ?? 0) > maxNum) {
        maxNum = value.differenceFloat ?? 0;
      }
    });
    expense.forEach((_, InsightTotalEntry value) {
      if ((value.differenceFloat ?? 0) > maxNum) {
        maxNum = value.differenceFloat ?? 0;
      }
    });
    if (maxNum >= 100000) {
      income.remove(income.keys.first);
      expense.remove(expense.keys.first);
    }

    return DashboardLastMonthsData(expense: expense, income: income);
  }

  Future<List<InsightGroupEntry>> fetchCategoryInsights({
    required bool tags,
  }) async {
    final DateTime now = tzHandler.sNow().clearTime();
    late final Response<InsightGroup> incomeResponse;
    late final Response<InsightGroup> expenseResponse;

    if (!tags) {
      (incomeResponse, expenseResponse) =
          await (
            api.v1InsightIncomeCategoryGet(
              start: DateFormat(
                'yyyy-MM-dd',
                'en_US',
              ).format(now.copyWith(day: 1)),
              end: DateFormat('yyyy-MM-dd', 'en_US').format(now),
            ),
            api.v1InsightExpenseCategoryGet(
              start: DateFormat(
                'yyyy-MM-dd',
                'en_US',
              ).format(now.copyWith(day: 1)),
              end: DateFormat('yyyy-MM-dd', 'en_US').format(now),
            ),
          ).wait;
    } else {
      (incomeResponse, expenseResponse) =
          await (
            api.v1InsightIncomeTagGet(
              start: DateFormat(
                'yyyy-MM-dd',
                'en_US',
              ).format(now.copyWith(day: 1)),
              end: DateFormat('yyyy-MM-dd', 'en_US').format(now),
            ),
            api.v1InsightExpenseTagGet(
              start: DateFormat(
                'yyyy-MM-dd',
                'en_US',
              ).format(now.copyWith(day: 1)),
              end: DateFormat('yyyy-MM-dd', 'en_US').format(now),
            ),
          ).wait;
    }
    apiThrowErrorIfEmpty(incomeResponse, null);
    apiThrowErrorIfEmpty(expenseResponse, null);

    final Map<String, double> incomes = <String, double>{};
    for (final InsightGroupEntry entry
        in incomeResponse.body ?? <InsightGroupEntry>[]) {
      final String? entryId = entry.id;
      if (entryId == null ||
          entryId.isEmpty ||
          entry.currencyId != defaultCurrency.id) {
        continue;
      }
      incomes[entryId] = entry.differenceFloat ?? 0;
    }

    final List<InsightGroupEntry> data = <InsightGroupEntry>[];
    for (final InsightGroupEntry entry in expenseResponse.body!) {
      final String? entryId = entry.id;
      if (entryId == null ||
          entryId.isEmpty ||
          entry.currencyId != defaultCurrency.id) {
        continue;
      }
      double amount = entry.differenceFloat ?? 0;
      if (incomes.containsKey(entryId)) {
        amount += incomes[entryId]!;
      }
      if (amount >= 0) {
        continue;
      }
      data.add(entry.copyWith(differenceFloat: amount));
    }

    return data;
  }

  Future<DashboardBudgetData> fetchBudgetData() async {
    final DateTime now = tzHandler.sNow().clearTime();
    final (
      Response<BudgetArray> budgetInfoResponse,
      Response<BudgetLimitArray> budgetLimitResponse,
    ) = await (
          api.v1BudgetsGet(),
          api.v1BudgetLimitsGet(
            start: DateFormat(
              'yyyy-MM-dd',
              'en_US',
            ).format(now.copyWith(day: 1)),
            end: DateFormat('yyyy-MM-dd', 'en_US').format(now),
          ),
        ).wait;
    apiThrowErrorIfEmpty(budgetInfoResponse, null);
    apiThrowErrorIfEmpty(budgetLimitResponse, null);

    final Map<String, BudgetProperties> budgetInfos =
        <String, BudgetProperties>{};
    for (final BudgetRead budget in budgetInfoResponse.body!.data) {
      budgetInfos[budget.id] = budget.attributes;
    }

    final List<BudgetLimitRead> budgetLimits = budgetLimitResponse.body!.data;
    budgetLimits.sort((BudgetLimitRead a, BudgetLimitRead b) {
      final BudgetProperties? budgetA = budgetInfos[a.attributes.budgetId];
      final BudgetProperties? budgetB = budgetInfos[b.attributes.budgetId];

      if (budgetA == null && budgetB != null) {
        return -1;
      } else if (budgetA != null && budgetB == null) {
        return 1;
      } else if (budgetA == null && budgetB == null) {
        return 0;
      }
      final int compare = (budgetA!.order ?? -1).compareTo(
        budgetB!.order ?? -1,
      );
      if (compare != 0) {
        return compare;
      }
      return a.attributes.start!.compareTo(b.attributes.start!);
    });

    return DashboardBudgetData(
      budgetInfos: budgetInfos,
      budgetLimits: budgetLimits,
    );
  }

  Future<List<BillRead>> fetchUpcomingBills() async {
    final DateTime now = tzHandler.sNow().clearTime();
    final DateTime end = now.copyWith(day: now.day + 7);
    final Response<BillArray> response = await api.v1BillsGet(
      start: DateFormat('yyyy-MM-dd', 'en_US').format(now),
      end: DateFormat('yyyy-MM-dd', 'en_US').format(end),
    );
    apiThrowErrorIfEmpty(response, null);

    return response.body!.data
        .where(
          (BillRead bill) => (bill.attributes.nextExpectedMatch != null
                  ? tzHandler.sTime(bill.attributes.nextExpectedMatch!)
                  : end.copyWith(day: end.day + 2))
              .toLocal()
              .clearTime()
              .isBefore(end.copyWith(day: end.day + 1)),
        )
        .toList(growable: false);
  }

  Future<DashboardBalanceData> fetchBalanceData() async {
    Map<DateTime, double> earned = <DateTime, double>{};
    Map<DateTime, double> spent = <DateTime, double>{};
    Map<DateTime, double> assets = <DateTime, double>{};
    Map<DateTime, double> liabilities = <DateTime, double>{};

    final DateTime now = tzHandler.sNow().clearTime();
    final DateTime end = now.copyWith(
      month: now.month + 1,
      day: 0,
      hour: 23,
      minute: 59,
      second: 59,
    );
    final DateTime start = now.copyWith(
      month: now.month - 11,
      day: 1,
      hour: 0,
      minute: 0,
      second: 0,
    );

    final (
      Response<AccountArray> assetResponse,
      Response<AccountArray> liabilityResponse,
      Response<List<ChartDataSet>> balanceResponse,
    ) = await (
          api.v1AccountsGet(type: AccountTypeFilter.asset),
          api.v1AccountsGet(type: AccountTypeFilter.liabilities),
          api.v1ChartAccountOverviewGet(
            start: DateFormat('yyyy-MM-dd', 'en_US').format(start),
            end: DateFormat('yyyy-MM-dd', 'en_US').format(end),
            preselected: V1ChartAccountOverviewGetPreselected.all,
            period: V1ChartAccountOverviewGetPeriod.value_1d,
          ),
        ).wait;
    apiThrowErrorIfEmpty(assetResponse, null);
    apiThrowErrorIfEmpty(liabilityResponse, null);
    apiThrowErrorIfEmpty(balanceResponse, null);

    final Map<String, bool> includeInNetWorth = <String, bool>{
      for (final AccountRead account in assetResponse.body!.data)
        account.attributes.name: account.attributes.includeNetWorth ?? true,
    };
    includeInNetWorth.addAll(<String, bool>{
      for (final AccountRead account in liabilityResponse.body!.data)
        account.attributes.name: account.attributes.includeNetWorth ?? true,
    });

    for (final ChartDataSet entry in balanceResponse.body!) {
      if (includeInNetWorth.containsKey(entry.label) &&
          includeInNetWorth[entry.label] != true) {
        continue;
      }
      final Map<String, dynamic> entries =
          entry.entries as Map<String, dynamic>;
      entries.forEach((String dateStr, dynamic valueStr) {
        DateTime date = tzHandler.sTime(DateTime.parse(dateStr)).toLocal();
        if ((date.month == now.month &&
                date.year == now.year &&
                date.day == now.day) ||
            (date.month != now.month &&
                date.copyWith(day: date.day + 1).month != date.month)) {
          final double value = double.tryParse(valueStr) ?? 0;
          date = date.copyWith(day: 1);
          if (value > 0) {
            assets[date] = (assets[date] ?? 0) + value;
          }
          if (value < 0) {
            liabilities[date] = (liabilities[date] ?? 0) + value;
          }
        }
      });
    }

    earned = _fillMissingMonths(earned, monthCount: 3, anchor: now);
    spent = _fillMissingMonths(spent, monthCount: 3, anchor: now);
    assets = _fillMissingMonths(assets, monthCount: 12, anchor: now);
    liabilities = _fillMissingMonths(liabilities, monthCount: 12, anchor: now);

    return DashboardBalanceData(
      earned: earned,
      spent: spent,
      assets: assets,
      liabilities: liabilities,
    );
  }

  static Map<DateTime, double> _fillMissingMonths(
    Map<DateTime, double> input, {
    required int monthCount,
    required DateTime anchor,
  }) {
    if (input.length < monthCount) {
      final DateTime lastDate = anchor.copyWith(day: 1);
      for (int i = 0; i < monthCount; i++) {
        final DateTime newDate = lastDate.copyWith(month: lastDate.month - i);
        input[newDate] = input[newDate] ?? 0;
      }
    }

    return Map<DateTime, double>.fromEntries(
      input.entries.toList()..sortBy((MapEntry<DateTime, double> e) => e.key),
    );
  }
}
