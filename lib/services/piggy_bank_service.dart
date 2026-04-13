import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

class AccountStatusData {
  const AccountStatusData({
    required this.account,
    required this.currency,
    required this.accountBalance,
    required this.totalInPiggyBanks,
    required this.availableBalance,
  });

  final AccountRead account;
  final CurrencyRead currency;
  final double accountBalance;
  final double totalInPiggyBanks;
  final double availableBalance;
}

class PiggyBankPageResult {
  const PiggyBankPageResult({
    required this.piggyBanks,
    required this.isLastPage,
    required this.accountStatusData,
  });

  final List<PiggyBankRead> piggyBanks;
  final bool isLastPage;
  final List<AccountStatusData> accountStatusData;
}

class PiggyBankService {
  const PiggyBankService({required this.api, required this.defaultCurrency});

  final FireflyIii api;
  final CurrencyRead defaultCurrency;

  Future<PiggyBankPageResult> fetchPage({
    required int page,
    required int limit,
  }) async {
    final Response<PiggyBankArray> response = await api.v1PiggyBanksGet(
      page: page,
      limit: limit,
    );
    apiThrowErrorIfEmpty(response, null);

    final List<PiggyBankRead> piggyBanks = response.body!.data;
    piggyBanks.sortByCompare(
      (PiggyBankRead element) => element.attributes.objectGroupOrder,
      (int? a, int? b) => (a ?? 0).compareTo(b ?? 0),
    );

    return PiggyBankPageResult(
      piggyBanks: piggyBanks,
      isLastPage: piggyBanks.length < limit,
      accountStatusData: await buildAccountStatusData(
        api: api,
        piggyBanks: piggyBanks,
        defaultCurrency: defaultCurrency,
      ),
    );
  }

  static Future<List<AccountStatusData>> buildAccountStatusData({
    required FireflyIii api,
    required List<PiggyBankRead> piggyBanks,
    required CurrencyRead defaultCurrency,
  }) async {
    final Map<String, double> accountIdToPiggyTotal = <String, double>{};
    for (final PiggyBankRead piggy in piggyBanks) {
      if (!(piggy.attributes.active ?? false) ||
          piggy.attributes.accounts == null) {
        continue;
      }
      for (final PiggyBankAccountRead account in piggy.attributes.accounts!) {
        if ((account.accountId ?? '').isEmpty) {
          continue;
        }
        final double amount = double.tryParse(account.currentAmount ?? "") ?? 0;
        accountIdToPiggyTotal.update(
          account.accountId!,
          (double previous) => previous + amount,
          ifAbsent: () => amount,
        );
      }
    }

    if (accountIdToPiggyTotal.isEmpty) {
      return const <AccountStatusData>[];
    }

    final List<AccountStatusData> statusData = <AccountStatusData>[];
    for (final MapEntry<String, double> entry
        in accountIdToPiggyTotal.entries) {
      final Response<AccountSingle> accountResponse = await api.v1AccountsIdGet(
        id: entry.key,
      );
      apiThrowErrorIfEmpty(accountResponse, null);

      final AccountRead account = accountResponse.body!.data;
      final double accountBalance =
          double.tryParse(account.attributes.currentBalance ?? "") ?? 0;
      final double totalInPiggyBanks = entry.value;
      final double availableBalance = accountBalance - totalInPiggyBanks;

      CurrencyRead currency = CurrencyRead(
        id: account.attributes.currencyId ?? "0",
        type: "currencies",
        attributes: CurrencyProperties(
          code: account.attributes.currencyCode ?? "",
          name: "",
          symbol: account.attributes.currencySymbol ?? "",
          decimalPlaces: account.attributes.currencyDecimalPlaces,
        ),
      );
      if (currency.id == "0") {
        currency = defaultCurrency;
      }

      statusData.add(
        AccountStatusData(
          account: account,
          currency: currency,
          accountBalance: accountBalance,
          totalInPiggyBanks: totalInPiggyBanks,
          availableBalance: availableBalance,
        ),
      );
    }

    return statusData;
  }
}
