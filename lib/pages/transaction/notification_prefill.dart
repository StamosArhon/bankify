import 'package:chopper/chopper.dart' show Response;
import 'package:bankify/extensions.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/notificationlistener.dart';
import 'package:bankify/settings.dart';

class TransactionNotificationPrefillDraft {
  const TransactionNotificationPrefillDraft({
    required this.type,
    required this.title,
    required this.note,
    required this.sourceAccountName,
    required this.sourceAccountType,
    required this.ownAccountId,
    required this.localCurrency,
    required this.localAmount,
    required this.foreignCurrency,
    required this.foreignAmount,
  });

  final TransactionTypeProperty type;
  final String title;
  final String note;
  final String sourceAccountName;
  final AccountTypeProperty sourceAccountType;
  final String? ownAccountId;
  final CurrencyRead localCurrency;
  final double localAmount;
  final CurrencyRead? foreignCurrency;
  final double foreignAmount;
}

class TransactionNotificationPrefillAdapter {
  const TransactionNotificationPrefillAdapter._();

  static Future<TransactionNotificationPrefillDraft?> build({
    required FireflyIii api,
    required SettingsProvider settings,
    required NotificationTransaction notification,
    required CurrencyRead initialLocalCurrency,
    required CurrencyRead defaultCurrency,
  }) async {
    CurrencyRead? currency;
    double amount;

    (currency, amount) = await parseNotificationText(
      api,
      notification.body,
      initialLocalCurrency,
    );

    currency ??= defaultCurrency;

    final NotificationAppSettings appSettings = await settings
        .notificationGetAppSettings(notification.appName);

    String title = '';
    String note = '';
    if (appSettings.includeTitle) {
      title = notification.title;
    } else {
      note = notification.title;
    }

    if (!appSettings.emptyNote) {
      note = notification.body;
    }

    final Response<AccountArray> response = await api.v1AccountsGet(
      type: AccountTypeFilter.assetAccount,
    );
    if (!response.isSuccessful || response.body == null) {
      return null;
    }

    AccountRead? matchedAccount;
    final String settingAppId = appSettings.defaultAccountId ?? "0";
    for (final AccountRead account in response.body!.data) {
      if (account.id == settingAppId ||
          notification.body.containsIgnoreCase(account.attributes.name)) {
        matchedAccount = account;
        break;
      }
    }

    CurrencyRead localCurrency = initialLocalCurrency;
    CurrencyRead? foreignCurrency;
    double localAmount = 0;
    double foreignAmount = 0;

    if (matchedAccount != null) {
      if (currency.id == matchedAccount.attributes.currencyId) {
        localCurrency = currency;
        localAmount = amount;
      } else {
        localCurrency = CurrencyRead(
          type: "currencies",
          id: matchedAccount.attributes.currencyId!,
          attributes: CurrencyProperties(
            code: matchedAccount.attributes.currencyCode!,
            name: "",
            symbol: matchedAccount.attributes.currencySymbol!,
            decimalPlaces: matchedAccount.attributes.currencyDecimalPlaces,
          ),
        );
        foreignCurrency = currency;
        foreignAmount = amount;
      }
    } else if (currency.id == initialLocalCurrency.id) {
      localAmount = amount;
    } else {
      foreignCurrency = currency;
      foreignAmount = amount;
    }

    return TransactionNotificationPrefillDraft(
      type: TransactionTypeProperty.withdrawal,
      title: title,
      note: note,
      sourceAccountName: matchedAccount?.attributes.name ?? "",
      sourceAccountType: AccountTypeProperty.assetAccount,
      ownAccountId: matchedAccount?.id,
      localCurrency: localCurrency,
      localAmount: localAmount,
      foreignCurrency: foreignCurrency,
      foreignAmount: foreignAmount,
    );
  }
}
