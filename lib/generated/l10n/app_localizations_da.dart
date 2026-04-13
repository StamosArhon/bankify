// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class SDa extends S {
  SDa([String locale = 'da']) : super(locale);

  @override
  String get accountRoleAssetCashWallet => 'Kontantstegnebog';

  @override
  String get accountRoleAssetCC => 'Kreditkort';

  @override
  String get accountRoleAssetDefault => 'Standard aktivkonto';

  @override
  String get accountRoleAssetSavings => 'Opsparingskonto';

  @override
  String get accountRoleAssetShared => 'Delt aktivkonto';

  @override
  String get accountsLabelAsset => 'Aktivkonti';

  @override
  String get accountsLabelExpense => 'Udgiftskonti';

  @override
  String get accountsLabelLiabilities => 'Gældsforpligtelser';

  @override
  String get accountsLabelRevenue => 'Indtægtskonti';

  @override
  String accountsLiabilitiesInterest(double interest, String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'weekly': 'uge',
      'monthly': 'måned',
      'quarterly': 'kvartal',
      'halfyear': 'halvår',
      'yearly': 'år',
      'other': 'ukendt',
    });
    return '$interest% renter per $_temp0';
  }

  @override
  String billsAmountAndFrequency(
    String minValue,
    String maxvalue,
    String frequency,
    num skip,
  ) {
    String _temp0 = intl.Intl.selectLogic(frequency, {
      'weekly': 'ugentligt',
      'monthly': 'månedligt',
      'quarterly': 'kvartalsvis',
      'halfyear': 'halvårligt',
      'yearly': 'årligt',
      'other': 'ukendt',
    });
    String _temp1 = intl.Intl.pluralLogic(
      skip,
      locale: localeName,
      other: ', springer over $skip',
      zero: '',
    );
    return 'Abonnement matcher transaktioner mellem $minValue og $maxvalue. Gentages $_temp0$_temp1.';
  }

  @override
  String get billsChangeLayoutTooltip => 'Skift layout';

  @override
  String get billsChangeSortOrderTooltip => 'Skift sorteringsrækkefølge';

  @override
  String get billsErrorLoading => 'Fejl ved indlæsning af abonnementer.';

  @override
  String get billsEmptyTitle => 'No subscriptions to show.';

  @override
  String get billsEmptySubtitle =>
      'Try changing the filters or add subscriptions in Firefly III.';

  @override
  String billsExactAmountAndFrequency(
    String value,
    String frequency,
    num skip,
  ) {
    String _temp0 = intl.Intl.selectLogic(frequency, {
      'weekly': 'ugentligt',
      'monthly': 'månedligt',
      'quarterly': 'kvartalsvis',
      'halfyear': 'halvårligt',
      'yearly': 'årligt',
      'other': 'ukendt',
    });
    String _temp1 = intl.Intl.pluralLogic(
      skip,
      locale: localeName,
      other: ', springer over $skip',
      zero: '',
    );
    return 'Abonnement matcher transaktioner af $value. Gentages $_temp0$_temp1.';
  }

  @override
  String billsExpectedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Forventet $dateString';
  }

  @override
  String billsFrequency(String frequency) {
    String _temp0 = intl.Intl.selectLogic(frequency, {
      'weekly': 'Ugentlig',
      'monthly': 'Månedlig',
      'quarterly': 'Kvartalsvis',
      'halfyear': 'Halvårlig',
      'yearly': 'Årlig',
      'other': 'Ukendt',
    });
    return '$_temp0';
  }

  @override
  String billsFrequencySkip(String frequency, num skip) {
    String _temp0 = intl.Intl.selectLogic(frequency, {
      'weekly': 'Ugentlig',
      'monthly': 'Månedlig',
      'quarterly': 'Kvartalsvis',
      'halfyear': 'Halvårlig',
      'yearly': 'Årlig',
      'other': 'Ukendt',
    });
    String _temp1 = intl.Intl.pluralLogic(
      skip,
      locale: localeName,
      other: ', springer over $skip',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String get billsInactive => 'Inaktiv';

  @override
  String get billsIsActive => 'Abonnementet er aktivt';

  @override
  String get billsLayoutGroupSubtitle =>
      'Abonnementer vises i deres tildelte grupper.';

  @override
  String get billsLayoutGroupTitle => 'Gruppe';

  @override
  String get billsLayoutListSubtitle =>
      'Abonnementer vises på en liste sorteret efter bestemte kriterier.';

  @override
  String get billsLayoutListTitle => 'Liste';

  @override
  String get billsListEmpty => 'Listen er i øjeblikket tom.';

  @override
  String get billsNextExpectedMatch => 'Næste forventede match';

  @override
  String get billsNotActive => 'Abonnementet er inaktivt';

  @override
  String get billsNotExpected => 'Ikke forventet i denne periode';

  @override
  String get billsNoTransactions => 'Ingen transaktioner fundet.';

  @override
  String billsPaidOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Betalt $dateString';
  }

  @override
  String get billsSortAlphabetical => 'Alfabetisk';

  @override
  String get billsSortByTimePeriod => 'Efter tidsperiode';

  @override
  String get billsSortFrequency => 'Frekvens';

  @override
  String get billsSortName => 'Navn';

  @override
  String get billsUngrouped => 'Ugrupperede';

  @override
  String get billsSettingsShowOnlyActive => 'Vis kun aktive';

  @override
  String get billsSettingsShowOnlyActiveDesc =>
      'Viser kun aktive abonnementer.';

  @override
  String get billsSettingsShowOnlyExpected => 'Vis kun forventede';

  @override
  String get billsSettingsShowOnlyExpectedDesc =>
      'Viser kun de abonnementer, der forventes (eller er betalt) denne måned.';

  @override
  String get categoryDeleteConfirm =>
      'Er du sikker på, at du vil slette denne kategori? Transaktionerne vil ikke blive slettet, men vil ikke længere have en kategori.';

  @override
  String get categoryErrorLoading => 'Fejl ved indlæsning af kategorier.';

  @override
  String get categoryFormLabelIncludeInSum => 'Medregn i månedlig sum';

  @override
  String get categoryFormLabelName => 'Kategorinavn';

  @override
  String get categoryMonthNext => 'Næste måned';

  @override
  String get categoryMonthPrev => 'Sidste måned';

  @override
  String get categorySumExcluded => 'udelukket';

  @override
  String get categoryTitleAdd => 'Tilføj kategori';

  @override
  String get categoryTitleDelete => 'Slet kategori';

  @override
  String get categoryTitleEdit => 'Redigér kategori';

  @override
  String get catNone => '<ingen kategori>';

  @override
  String get catOther => 'Andet';

  @override
  String errorAPIInvalidResponse(String message) {
    return 'Ugyldigt svar fra API: $message';
  }

  @override
  String get errorAPIUnavailable => 'API utilgængelig';

  @override
  String get errorFieldRequired => 'Dette felt er påkrævet.';

  @override
  String get errorInvalidURL => 'Ugyldig URL';

  @override
  String errorMinAPIVersion(String requiredVersion) {
    return 'Minimum Firefly API-version v$requiredVersion påkrævet. Opgradér venligst.';
  }

  @override
  String errorStatusCode(int code) {
    return 'Statuskode: $code';
  }

  @override
  String get errorUnknown => 'Ukendt fejl.';

  @override
  String get formButtonHelp => 'Hjælp';

  @override
  String get formButtonLogin => 'Log ind';

  @override
  String get formButtonLogout => 'Log ud';

  @override
  String get formButtonRemove => 'Fjern';

  @override
  String get formButtonResetLogin => 'Nulstil login';

  @override
  String get formButtonTransactionAdd => 'Tilføj transaktion';

  @override
  String get formButtonTryAgain => 'Prøv igen';

  @override
  String get generalAccount => 'Konto';

  @override
  String get generalAssets => 'Aktiver';

  @override
  String get generalBalance => 'Saldo';

  @override
  String generalBalanceOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Saldo på $dateString';
  }

  @override
  String get generalBill => 'Regning';

  @override
  String get generalBudget => 'Budgetter';

  @override
  String get generalCategory => 'Kategori';

  @override
  String get generalCurrency => 'Valuta';

  @override
  String get generalDateRangeCurrentMonth => 'Nuværende måned';

  @override
  String get generalDateRangeLast30Days => 'Sidste 30 dage';

  @override
  String get generalDateRangeCurrentYear => 'Nuværende år';

  @override
  String get generalDateRangeLastYear => 'Sidste år';

  @override
  String get generalDateRangeAll => 'Alle';

  @override
  String get generalDefault => 'standard';

  @override
  String get generalDestinationAccount => 'Destinationskonto';

  @override
  String get generalDismiss => 'Afvis';

  @override
  String get generalEarned => 'Optjent';

  @override
  String get generalError => 'Fejl';

  @override
  String get generalLoading => 'Loading';

  @override
  String get generalNothingToShow => 'Nothing to show yet';

  @override
  String get generalRetry => 'Retry';

  @override
  String get generalExpenses => 'Udgifter';

  @override
  String get generalIncome => 'Indtægter';

  @override
  String get generalLiabilities => 'Gældsforpligtelser';

  @override
  String get generalMultiple => 'flere';

  @override
  String get generalNever => 'aldrig';

  @override
  String get generalReconcile => 'Afstemt';

  @override
  String get generalReset => 'Nulstil';

  @override
  String get generalSourceAccount => 'Kildekonto';

  @override
  String get generalSpent => 'Brugt';

  @override
  String get generalSum => 'I alt';

  @override
  String get generalTarget => 'Mål';

  @override
  String get generalUnknown => 'Ukendt';

  @override
  String homeMainBillsInterval(String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'weekly': 'ugentligt',
      'monthly': 'månedligt',
      'quarterly': 'kvartalsvis',
      'halfyear': 'halvårligt',
      'yearly': 'årligt',
      'other': 'ukendt',
    });
    return '($_temp0)';
  }

  @override
  String get homeMainBillsTitle => 'Regninger for næste uge';

  @override
  String homeMainBudgetInterval(DateTime from, DateTime to, String period) {
    final intl.DateFormat fromDateFormat = intl.DateFormat.MMMd(localeName);
    final String fromString = fromDateFormat.format(from);
    final intl.DateFormat toDateFormat = intl.DateFormat.MMMd(localeName);
    final String toString = toDateFormat.format(to);

    return '($fromString til $toString, $period)';
  }

  @override
  String homeMainBudgetIntervalSingle(DateTime from, DateTime to) {
    final intl.DateFormat fromDateFormat = intl.DateFormat.MMMd(localeName);
    final String fromString = fromDateFormat.format(from);
    final intl.DateFormat toDateFormat = intl.DateFormat.MMMd(localeName);
    final String toString = toDateFormat.format(to);

    return '($fromString til $toString)';
  }

  @override
  String homeMainBudgetSum(String current, String status, String available) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'over': 'over',
      'other': 'tilbage af',
    });
    return '$current$_temp0 $available';
  }

  @override
  String get homeMainBudgetTitle => 'Budgetter for denne måned';

  @override
  String get homeMainChartAccountsTitle => 'Kontooversigt';

  @override
  String get homeMainChartCategoriesTitle => 'Kategorioversigt for denne måned';

  @override
  String get homeMainChartDailyAvg => '7 dages-gennemsnit';

  @override
  String get homeMainChartDailyTitle => 'Dagsoversigt';

  @override
  String get homeMainChartNetEarningsTitle => 'Nettoindtjening';

  @override
  String get homeMainChartNetWorthTitle => 'Nettoværdi';

  @override
  String get homeMainChartTagsTitle => 'Tag-oversigt for nuværende måned';

  @override
  String get homePiggyAdjustDialogTitle => 'Gem/brug penge';

  @override
  String homePiggyDateStart(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Startdato: $dateString';
  }

  @override
  String homePiggyDateTarget(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Måldato: $dateString';
  }

  @override
  String get homeMainDialogSettingsTitle => 'Tilpas Dashboard';

  @override
  String homePiggyLinked(String account) {
    return 'Knyttet til $account';
  }

  @override
  String get homePiggyNoAccounts => 'Ingen sparegris er sat op.';

  @override
  String get homePiggyNoAccountsSubtitle => 'Opret nogle i webgrænsefladen!';

  @override
  String get homeBalanceEmptyTitle => 'No asset accounts to show.';

  @override
  String get homeBalanceEmptySubtitle =>
      'Accounts with balances will appear here.';

  @override
  String get accountsEmptySubtitle =>
      'Accounts in this category will appear here once they exist in Firefly III.';

  @override
  String homePiggyRemaining(String amount) {
    return 'Mangler at spare: $amount';
  }

  @override
  String homePiggySaved(String amount) {
    return 'Gemt indtil videre: $amount';
  }

  @override
  String get homePiggySavedMultiple => 'Opsparet indtil videre:';

  @override
  String homePiggyTarget(String amount) {
    return 'Målbeløb: $amount';
  }

  @override
  String get homePiggyAccountStatus => 'Kontostatus';

  @override
  String get homePiggyAvailableAmounts => 'Tilgængelige beløb';

  @override
  String homePiggyAvailable(String amount) {
    return 'Tilgængelig: $amount';
  }

  @override
  String homePiggyInPiggyBanks(String amount) {
    return 'I sparegrise: $amount';
  }

  @override
  String get homeTabLabelBalance => 'Balance';

  @override
  String get homeTabLabelMain => 'Primær';

  @override
  String get homeTabLabelPiggybanks => 'Sparegrise';

  @override
  String get homeTabLabelTransactions => 'Transaktioner';

  @override
  String get homeTransactionsActionFilter => 'Filterliste';

  @override
  String get homeTransactionsDialogFilterAccountsAll => '<Alle konti>';

  @override
  String get homeTransactionsDialogFilterBillsAll => '<All Bills>';

  @override
  String get homeTransactionsDialogFilterBillUnset => '<No Bill set>';

  @override
  String get homeTransactionsDialogFilterBudgetsAll => '<Alle budgetter>';

  @override
  String get homeTransactionsDialogFilterBudgetUnset =>
      '<Intet budget tildelt>';

  @override
  String get homeTransactionsDialogFilterCategoriesAll => '<Alle kategorier>';

  @override
  String get homeTransactionsDialogFilterCategoryUnset =>
      '<Ingen kategori tildelt>';

  @override
  String get homeTransactionsDialogFilterCurrenciesAll => '<Alle valutaer>';

  @override
  String get homeTransactionsDialogFilterDateRange => 'Datointerval';

  @override
  String get homeTransactionsDialogFilterFutureTransactions =>
      'Vis fremtidige transaktioner';

  @override
  String get homeTransactionsDialogFilterSearch => 'Søgeord';

  @override
  String get homeTransactionsDialogFilterTitle => 'Vælg filtre';

  @override
  String get homeTransactionsPresetSectionTitle => 'Saved presets';

  @override
  String get homeTransactionsPresetSaveAction => 'Save preset';

  @override
  String get homeTransactionsPresetSaveTitle => 'Save filter preset';

  @override
  String get homeTransactionsPresetNameLabel => 'Preset name';

  @override
  String get homeTransactionsActionNewFromTemplate => 'New from template';

  @override
  String get homeTransactionsEmpty => 'Ingen transaktioner fundet.';

  @override
  String homeTransactionsMultipleCategories(int num) {
    return '$num kategorier';
  }

  @override
  String get homeTransactionsSettingsShowTags =>
      'Vis tags på transaktionslisten';

  @override
  String get liabilityDirectionCredit => 'Jeg er skyldt denne gæld';

  @override
  String get liabilityDirectionDebit => 'Jeg skylder denne gæld';

  @override
  String get liabilityTypeDebt => 'Gæld';

  @override
  String get liabilityTypeLoan => 'Lån';

  @override
  String get liabilityTypeMortgage => 'Boliglån';

  @override
  String get loginAbout =>
      'For at bruge Bankify produktivt har du brug for din egen server med en Firefly III-instans eller Firefly II-add-on til Home Assistant.\n\nIndtast venligst det fulde URL samt en personlig adgangstoken (Indstillinger -> Profil -> OAuth -> Personlig adgangstoken) nedenfor.';

  @override
  String get loginFormLabelAPIKey => 'Gyldig API-nøgle';

  @override
  String get loginFormLabelHost => 'Værts-URL';

  @override
  String get loginWelcome => 'Velkommen til Bankify';

  @override
  String get logoutConfirmation => 'Er du sikker på, at du vil logge ud?';

  @override
  String get navigationAccounts => 'Konti';

  @override
  String get navigationBills => 'Abonnementer';

  @override
  String get navigationCategories => 'Kategorier';

  @override
  String get navigationMain => 'Hoveddashboard';

  @override
  String get generalSettings => 'Indstillinger';

  @override
  String get no => 'Nej';

  @override
  String numPercent(double num) {
    final intl.NumberFormat numNumberFormat = intl
        .NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: 0,
    );
    final String numString = numNumberFormat.format(num);

    return '$numString';
  }

  @override
  String numPercentOf(double perc, String of) {
    final intl.NumberFormat percNumberFormat = intl
        .NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: 0,
    );
    final String percString = percNumberFormat.format(perc);

    return '$percString af $of';
  }

  @override
  String get settingsDialogDebugInfo =>
      'Du kan aktivere og sende fejfindingslogs her. Disse har en dårlig indvirkning på ydeevnen, så du skal venligst ikke aktivere dem, medmindre du rådes til at gøre det. Deaktivering af logning vil slette den gemte log.';

  @override
  String get settingsDialogDebugMailCreate => 'Opret mail';

  @override
  String get settingsDialogDebugMailDisclaimer =>
      'ADVARSEL: En mailkladde åbnes med logfilen vedhæftet (i tekstformat). Logfilerne kan indeholdet følsomme oplysninger, såsom værtsnavnet på din Firefly instans (selvom jeg forsøger at undgå logning af eventuelle hemmeligheder, såsom api-nøgle). Læs venligst loggen grundigt og censurér alle oplysninger, du ikke ønsker at dele og/eller ikke er relevante for det problem, du ønsker at rapportere.';

  @override
  String get settingsDialogDebugSendButton => 'Send logfiler via e-mail';

  @override
  String get settingsDialogDebugTitle => 'Fejlfindingslogs';

  @override
  String get settingsDialogLanguageTitle => 'Vælg sprog';

  @override
  String get settingsDialogThemeTitle => 'Vælg tema';

  @override
  String get settingsFAQ => 'Ofte stillede spørgsmål';

  @override
  String get settingsFAQHelp =>
      'Åbnes i browseren. Kun tilgængelig på engelsk.';

  @override
  String get settingsLanguage => 'Sprog';

  @override
  String get settingsLockscreen => 'Låst skærm';

  @override
  String get settingsLockscreenHelp => 'Kræv godkendelse ved opstart af app';

  @override
  String get settingsLockscreenInitial =>
      'Godkend venligst for at aktivere skærmlåsning.';

  @override
  String get settingsLockTimeout => 'Lock again after';

  @override
  String get settingsLockTimeoutHelp =>
      'How long Bankify may stay in the background before it asks for authentication again.';

  @override
  String get settingsLockTimeoutDialogTitle => 'Choose lock timeout';

  @override
  String get settingsLockTimeoutImmediate => 'Immediately';

  @override
  String get settingsLockTimeoutOneMinute => '1 minute';

  @override
  String get settingsLockTimeoutFiveMinutes => '5 minutes';

  @override
  String get settingsLockTimeoutTenMinutes => '10 minutes';

  @override
  String get settingsLockTimeoutThirtyMinutes => '30 minutes';

  @override
  String get settingsNLAppAccount => 'Standard konto';

  @override
  String get settingsNLAppAccountDynamic => '<Dynamisk>';

  @override
  String get settingsNLAppAdd => 'Tilføj app';

  @override
  String get settingsNLAppAddHelp =>
      'Klik for at tilføje en app til at lytte til. Kun kvalificerede apps vil dukke op på listen.';

  @override
  String get settingsNLAppAddInfo =>
      'Foretag nogle transaktioner, hvor du modtager telefonmeddelelser for at tilføje apps til denne liste. Hvis appen stadig ikke dukker op, bedes du rapportere den til github.com/StamosArhon/bankify/issues.';

  @override
  String get settingsNLAppObservedPackage => 'Observed package name';

  @override
  String get settingsNLAutoAdd => 'Opret transaktion uden interaktion';

  @override
  String get settingsNLDescription =>
      'Denne tjeneste giver dig mulighed for at hente transaktionsoplysninger fra indgående push-notifikationer. Derudover kan du vælge en standardkonto, som transaktionen skal tildeles til - hvis ingen værdi er angivet, vil den prøve at udtrække en konto fra notifikationen.';

  @override
  String get settingsNLEmptyNote => 'Lad notatfeltet være tomt';

  @override
  String get settingsNLPermissionGrant => 'Tryk for at give tilladelse.';

  @override
  String get settingsNLPermissionNotGranted => 'Tilladelse ikke givet.';

  @override
  String get settingsNLPermissionRemove => 'Fjern tilladelse?';

  @override
  String get settingsNLPermissionRemoveHelp =>
      'Klik på appen for at deaktivere denne tjeneste og fjern tilladelserne på den næste skærm.';

  @override
  String get settingsNLPrefillTXTitle =>
      'Forudfyld transaktionstitel med nofikationstitel';

  @override
  String get settingsNLServiceChecking => 'Tjekker status…';

  @override
  String settingsNLServiceCheckingError(String error) {
    return 'Fejl under kontrol af status: $error';
  }

  @override
  String get settingsNLServiceRunning => 'Tjenesten kører.';

  @override
  String get settingsNLServiceStatus => 'Tjenestestatus';

  @override
  String get settingsNLServiceStopped => 'Tjenesten er stoppet.';

  @override
  String get settingsNotificationListener => 'Notifikationslytter-service';

  @override
  String get settingsTheme => 'App tema';

  @override
  String get settingsThemeDynamicColors => 'Dynamisk farve';

  @override
  String settingsThemeValue(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'dark': 'Mørk tilstand',
      'light': 'Lys tilstand',
      'other': 'Systemstandard',
    });
    return '$_temp0';
  }

  @override
  String get settingsUseServerTimezone => 'Brug serverens tidszone';

  @override
  String get settingsUseServerTimezoneHelp =>
      'Vis alle gange i serverens tidszone. Dette efterligner webgrænsefladens opførsel.';

  @override
  String get settingsVersion => 'Appversion';

  @override
  String get settingsVersionChecking => 'tjekker…';

  @override
  String get transactionAttachments => 'Bilag';

  @override
  String get transactionDeleteConfirm =>
      'Er du sikker på, at du vil slette denne transaktion?';

  @override
  String get transactionDialogAttachmentsDelete => 'Slet bilag';

  @override
  String get transactionDialogAttachmentsDeleteConfirm =>
      'Er du sikker på, at du vil slette dette bilag?';

  @override
  String get transactionDialogAttachmentsErrorDownload =>
      'Kunne ikke downloade fil.';

  @override
  String transactionDialogAttachmentsErrorOpen(String error) {
    return 'Kunne ikke åbne fil: $error';
  }

  @override
  String transactionDialogAttachmentsErrorUpload(String error) {
    return 'Kunne ikke uploade fil: $error';
  }

  @override
  String get transactionDialogAttachmentsTitle => 'Bilag';

  @override
  String get transactionDialogAttachmentsOpenExternalTitle =>
      'Open attachment in another app?';

  @override
  String transactionDialogAttachmentsOpenExternalBody(String fileName) {
    return 'Bankify will ask Android to hand \"$fileName\" to another app. Only continue if you trust the file and expect another app to open it.';
  }

  @override
  String get transactionDialogAttachmentsOpenExternalConfirm =>
      'Open in another app';

  @override
  String get transactionSharedAttachmentsReviewTitle =>
      'Review shared attachments';

  @override
  String get transactionSharedAttachmentsReviewBody =>
      'Bankify only accepts images and PDF files shared from local storage. Review these files before adding them to this transaction.';

  @override
  String get transactionSharedAttachmentsAcceptedTitle => 'Ready to add';

  @override
  String get transactionSharedAttachmentsRejectedTitle => 'Not added';

  @override
  String get transactionSharedAttachmentsTemporaryCopy => 'Temporary app copy';

  @override
  String get transactionSharedAttachmentsAccept => 'Add attachments';

  @override
  String get transactionSharedAttachmentsDiscard => 'Discard';

  @override
  String get transactionSharedAttachmentsClose => 'Close';

  @override
  String get transactionSharedAttachmentsRejectedEmpty =>
      'The shared item did not contain a usable file path.';

  @override
  String get transactionSharedAttachmentsRejectedUnsupportedType =>
      'Only images and PDF files can be shared to Bankify.';

  @override
  String get transactionSharedAttachmentsRejectedOrigin =>
      'The shared item did not resolve to a trusted local file.';

  @override
  String get transactionSharedAttachmentsRejectedMissingFile =>
      'Bankify could not read the shared file anymore.';

  @override
  String get transactionSharedAttachmentsRejectedDuplicate =>
      'Bankify already received this shared file path in the current share action.';

  @override
  String transactionSharedAttachmentsRejectedTooLarge(String maxSize) {
    return 'The shared file is larger than $maxSize.';
  }

  @override
  String transactionSharedAttachmentsRejectedLimit(int maxCount) {
    return 'Only the first $maxCount shared files are accepted at once.';
  }

  @override
  String get transactionDialogBillNoBill => 'Ingen regning';

  @override
  String get transactionDialogBillTitle => 'Link til regning';

  @override
  String get transactionDialogCurrencyTitle => 'Vælg valuta';

  @override
  String get transactionDialogPiggyNoPiggy => 'Ingen opsparingsmål';

  @override
  String get transactionDialogPiggyTitle => 'Knyt til opsparingsmål';

  @override
  String get transactionDialogTagsAdd => 'Tilføj etiket';

  @override
  String get transactionDialogTagsHint => 'Søg/Tilføj Tag';

  @override
  String get transactionDialogTagsTitle => 'Vælg etiketter';

  @override
  String get transactionDuplicate => 'Duplikér';

  @override
  String get transactionErrorInvalidAccount => 'Ugyldig konto';

  @override
  String get transactionErrorInvalidBudget => 'Ugyldigt Budget';

  @override
  String get transactionErrorNoAccounts => 'Udfyld venligst konti først.';

  @override
  String get transactionErrorNoAssetAccount => 'Vælg venligst en aktivkonto.';

  @override
  String get transactionErrorTitle => 'Angiv venligst en titel.';

  @override
  String get transactionFormLabelAccountDestination => 'Destinationskonto';

  @override
  String get transactionFormLabelAccountForeign => 'Fremmed konto';

  @override
  String get transactionFormLabelAccountOwn => 'Egen konto';

  @override
  String get transactionFormLabelAccountSource => 'Fra konto';

  @override
  String get transactionFormLabelNotes => 'Noter';

  @override
  String get transactionFormLabelTags => 'Etiketter';

  @override
  String get transactionFormLabelTitle => 'Transaktionstitel';

  @override
  String get transactionSplitAdd => 'Tilføj delt transaktion';

  @override
  String get transactionSplitChangeCurrency => 'Ændr delt valuta';

  @override
  String get transactionSplitChangeDestinationAccount =>
      'Skift destinationkonto for opdeling';

  @override
  String get transactionSplitChangeSourceAccount =>
      'Skift kildekonto for opdeling';

  @override
  String get transactionSplitChangeTarget => 'Ændr delt målkonto';

  @override
  String get transactionSplitDelete => 'Slet split';

  @override
  String get transactionSectionAttention =>
      'Finish these essentials before saving';

  @override
  String get transactionSectionAttentionMissingAccounts =>
      'Choose accounts so Bankify can determine the transaction type.';

  @override
  String get transactionSectionAttentionMissingOwnAccount =>
      'Select the asset or debt account that belongs to you.';

  @override
  String get transactionSectionAttentionMissingTitle =>
      'Add a transaction title.';

  @override
  String get transactionSectionAccounts => 'Accounts';

  @override
  String get transactionSectionAccountsSubtitle =>
      'Choose the accounts to let Bankify infer the transaction type.';

  @override
  String get transactionSectionOverview => 'Overview';

  @override
  String get transactionSectionOverviewSubtitle =>
      'Start with the title, amount, and date.';

  @override
  String get transactionSectionSplits => 'Line items';

  @override
  String transactionSectionSplitsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count line items',
      one: '1 line item',
    );
    return '$_temp0';
  }

  @override
  String get transactionAdvancedDetails => 'Advanced details';

  @override
  String get transactionAdvancedDetailsSubtitle =>
      'Optional fields and split actions';

  @override
  String transactionSplitLabel(int index) {
    return 'Line item $index';
  }

  @override
  String get transactionTitleAdd => 'Tilføj transaktion';

  @override
  String get transactionTitleDelete => 'Slet transaktion';

  @override
  String get transactionTitleEdit => 'Redigér transaktion';

  @override
  String get transactionTemplateApplyAction => 'Use template';

  @override
  String get transactionTemplateDeleteAction => 'Delete template';

  @override
  String get transactionTemplateDialogTitle => 'Transaction templates';

  @override
  String get transactionTemplateEmpty =>
      'Save a template from a transaction to reuse common fields later.';

  @override
  String get transactionTemplateNameLabel => 'Template name';

  @override
  String get transactionTemplateSaveAction => 'Save as template';

  @override
  String get transactionDraftResumeTitle => 'Resume saved draft?';

  @override
  String get transactionDraftResumeBody =>
      'Bankify found an unfinished transaction draft from an earlier session.';

  @override
  String get transactionDraftResumeAction => 'Resume draft';

  @override
  String get transactionDraftDiscardAction => 'Discard draft';

  @override
  String get transactionTypeDeposit => 'Indbetal';

  @override
  String get transactionTypeTransfer => 'Overfør';

  @override
  String get transactionTypeWithdrawal => 'Hævning';
}
