import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:badges/badges.dart' as badges;
import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:bankify/animations.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/extensions.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/notificationlistener.dart';
import 'package:bankify/pages/navigation.dart';
import 'package:bankify/pages/transaction/attachment_upload_service.dart';
import 'package:bankify/pages/transaction/attachments.dart';
import 'package:bankify/pages/transaction/bill.dart';
import 'package:bankify/pages/transaction/currencies.dart';
import 'package:bankify/pages/transaction/delete.dart';
import 'package:bankify/pages/transaction/editor_state_store.dart';
import 'package:bankify/pages/transaction/notification_prefill.dart';
import 'package:bankify/pages/transaction/payload.dart';
import 'package:bankify/pages/transaction/piggy.dart';
import 'package:bankify/pages/transaction/shared_attachments.dart';
import 'package:bankify/pages/transaction/tags.dart';
import 'package:bankify/pages/transaction/template_dialogs.dart';
import 'package:bankify/shared_attachment_intake.dart';
import 'package:bankify/settings.dart';
import 'package:bankify/stock.dart';
import 'package:bankify/timezonehandler.dart';
import 'package:bankify/widgets/autocompletetext.dart';
import 'package:bankify/widgets/input_number.dart';
import 'package:bankify/widgets/materialiconbutton.dart';

final Logger log = Logger("Pages.Transaction");

enum _TransactionToolbarAction { useTemplate, saveTemplate }

class TransactionPage extends StatefulWidget {
  const TransactionPage({
    super.key,
    this.transaction,
    this.notification,
    this.files,
    this.clone = false,
    this.accountId,
    this.onSharedFilesConsumed,
    this.templateSnapshot,
  });

  final TransactionRead? transaction;
  final NotificationTransaction? notification;
  final List<SharedFile>? files;
  final bool clone;
  final String? accountId;
  final VoidCallback? onSharedFilesConsumed;
  final TransactionEditorStateSnapshot? templateSnapshot;

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final Logger log = Logger("Pages.Transaction.Page");

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TransactionEditorStateStore _editorStateStore =
      TransactionEditorStateStore();

  // Common values
  late TransactionTypeProperty _transactionType;
  final TextEditingController _titleTextController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  String? _ownAccountId;
  late tz.TZDateTime _date;
  CurrencyRead? _localCurrency;
  bool _reconciled = false;
  bool _initiallyReconciled = false;

  // Individual for split transactions, show common for single transaction
  final TextEditingController _sourceAccountTextController =
      TextEditingController();
  final FocusNode _sourceAccountFocusNode = FocusNode();
  AccountTypeProperty _sourceAccountType =
      AccountTypeProperty.swaggerGeneratedUnknown;
  final TextEditingController _destinationAccountTextController =
      TextEditingController();
  final FocusNode _destinationAccountFocusNode = FocusNode();
  AccountTypeProperty _destinationAccountType =
      AccountTypeProperty.swaggerGeneratedUnknown;
  final TextEditingController _localAmountTextController =
      TextEditingController();

  // Always in card view
  final List<TextEditingController> _categoryTextControllers =
      <TextEditingController>[];
  final List<FocusNode> _categoryFocusNodes = <FocusNode>[];
  final List<TextEditingController> _budgetTextControllers =
      <TextEditingController>[];
  final List<FocusNode> _budgetFocusNodes = <FocusNode>[];
  final List<Tags> _tags = <Tags>[];
  final List<TextEditingController> _tagsTextControllers =
      <TextEditingController>[];
  final List<TextEditingController> _noteTextControllers =
      <TextEditingController>[];
  final List<BillRead?> _bills = <BillRead?>[];
  final List<PiggyBankRead?> _piggy = <PiggyBankRead?>[];

  // Individual for split transactions
  final List<TextEditingController> _titleTextControllers =
      <TextEditingController>[];
  final List<FocusNode> _titleFocusNodes = <FocusNode>[];
  final List<TextEditingController> _sourceAccountTextControllers =
      <TextEditingController>[];
  final List<FocusNode> _sourceAccountFocusNodes = <FocusNode>[];
  final List<TextEditingController> _destinationAccountTextControllers =
      <TextEditingController>[];
  final List<FocusNode> _destinationAccountFocusNodes = <FocusNode>[];
  final List<double> _localAmounts = <double>[];
  final List<TextEditingController> _localAmountTextControllers =
      <TextEditingController>[];
  final List<double> _foreignAmounts = <double>[];
  final List<TextEditingController> _foreignAmountTextControllers =
      <TextEditingController>[];
  final List<CurrencyRead?> _foreignCurrencies = <CurrencyRead?>[];
  final List<String?> _transactionJournalIDs = <String?>[];
  final List<String> _deletedSplitIDs = <String>[];

  bool _split = false;
  bool _hasAttachments = false;
  List<AttachmentRead>? _attachments;
  final Set<String> _managedSharedAttachmentPaths = <String>{};
  List<String> _managedSharedAttachmentRoots = <String>[];
  bool _txTypeChipExtended = false;
  bool _showSourceAccountSelection = false;
  bool _showDestinationAccountSelection = false;
  bool _attachmentLoadRequested = false;
  bool _savingInProgress = false;
  bool _clearDraftOnDispose = false;
  Timer? _draftSaveDebounce;

  late bool _newTX;

  late TimeZoneHandler _tzHandler;

  // Magic moving!
  // https://m3.material.io/styles/motion/easing-and-duration/applying-easing-and-duration
  final List<AnimationController> _cardsAnimationController =
      <AnimationController>[];
  final List<Animation<double>> _cardsAnimation = <Animation<double>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _newTX = widget.transaction == null || widget.clone;

    _tzHandler = context.read<FireflyService>().tzHandler;
    _registerSharedDraftListeners();

    if (widget.files?.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSharedFilesConsumed?.call();
      });
    }

    // opening an existing transaction, extract information
    if (widget.transaction != null) {
      final TransactionRead transaction = widget.transaction!;
      final List<TransactionSplit> transactions =
          transaction.attributes.transactions;

      // Common values
      /// type
      _transactionType = transactions.first.type;

      /// title
      if (transaction.attributes.groupTitle?.isNotEmpty ?? false) {
        _titleTextController.text = transaction.attributes.groupTitle!;
      } else {
        _titleTextController.text = transactions.first.description;
      }

      /// own account
      switch (_transactionType) {
        case TransactionTypeProperty.withdrawal:
        case TransactionTypeProperty.transfer:
          _ownAccountId = transactions.first.sourceId;
          break;
        case TransactionTypeProperty.deposit:
        case TransactionTypeProperty.openingBalance:
        case TransactionTypeProperty.reconciliation:
          _ownAccountId = transactions.first.destinationId;
          break;
        default:
      }

      /// date
      _date = _tzHandler.sTime(transactions.first.date).toLocal();

      /// account currency
      _localCurrency = CurrencyRead(
        type: "currencies",
        id: transactions.first.currencyId!,
        attributes: CurrencyProperties(
          code: transactions.first.currencyCode!,
          name: transactions.first.currencyName!,
          symbol: transactions.first.currencySymbol!,
          decimalPlaces: transactions.first.currencyDecimalPlaces,
        ),
      );

      // Reconciled
      _reconciled = transactions.first.reconciled ?? false;

      for (TransactionSplit trans in transactions) {
        // Always in card view
        /// Category
        _categoryTextControllers.add(
          TextEditingController(text: trans.categoryName),
        );
        _categoryFocusNodes.add(FocusNode());

        //// Budget
        _budgetTextControllers.add(
          TextEditingController(text: trans.budgetName),
        );
        _budgetFocusNodes.add(FocusNode());

        /// Tags
        _tags.add(Tags(trans.tags ?? <String>[]));
        _tagsTextControllers.add(
          TextEditingController(text: (_tags.last.tags.isNotEmpty) ? " " : ""),
        );

        /// Notes
        _noteTextControllers.add(TextEditingController(text: trans.notes));

        /// Bill
        if ((trans.billId?.isNotEmpty ?? false) && trans.billId != "0") {
          _bills.add(
            BillRead(
              type: "bill",
              id: trans.billId ?? "",
              attributes: BillProperties(
                name: trans.billName ?? "",
                amountMin: "",
                amountMax: "",
                date: DateTime.now(),
                repeatFreq: BillRepeatFrequency.swaggerGeneratedUnknown,
              ),
            ),
          );
        } else {
          _bills.add(null);
        }

        // Individual for split transactions
        /// Title
        _titleTextControllers.add(
          TextEditingController(text: trans.description),
        );
        _titleFocusNodes.add(FocusNode());

        /// local amount
        _localAmounts.add(double.tryParse(trans.amount) ?? 0);
        _localAmountTextControllers.add(
          TextEditingController(
            text: _localAmounts.last.toStringAsFixed(
              trans.currencyDecimalPlaces ?? 2,
            ),
          ),
        );

        /// source account
        _sourceAccountTextControllers.add(
          TextEditingController(text: trans.sourceName),
        );
        _sourceAccountFocusNodes.add(FocusNode());
        _sourceAccountType = trans.sourceType!;

        /// target account
        _destinationAccountTextControllers.add(
          TextEditingController(text: trans.destinationName),
        );
        _destinationAccountFocusNodes.add(FocusNode());
        _destinationAccountType = trans.destinationType!;

        /// foreign currency
        //// foreign amount
        _foreignAmounts.add(double.tryParse(trans.foreignAmount ?? '') ?? 0);
        _foreignAmountTextControllers.add(
          TextEditingController(
            text: _foreignAmounts.last.toStringAsFixed(
              trans.foreignCurrencyDecimalPlaces ?? 2,
            ),
          ),
        );
        //// foreign currency
        if (trans.foreignCurrencyCode?.isNotEmpty ?? false) {
          _foreignCurrencies.add(
            CurrencyRead(
              type: "currencies",
              id: trans.foreignCurrencyId!,
              attributes: CurrencyProperties(
                code: trans.foreignCurrencyCode!,
                name: "", // empty
                symbol: trans.foreignCurrencySymbol!,
                decimalPlaces: trans.foreignCurrencyDecimalPlaces,
              ),
            ),
          );
        } else {
          _foreignCurrencies.add(null);
        }

        //// Journal ID
        _transactionJournalIDs.add(trans.transactionJournalId);

        //// Attachments
        _hasAttachments = _hasAttachments || (trans.hasAttachments ?? false);

        //// Piggy (always zeroed out, only relevant for cloning)
        _piggy.add(null);

        // Card Animations
        _cardsAnimationController.add(
          AnimationController(
            // height 1 = visible - enter = fwd (0->1), exit = reverse (1->0)
            value: 1.0,
            duration: animDurationEmphasizedDecelerate,
            reverseDuration: animDurationEmphasizedDecelerate,
            vsync: this,
          ),
        );
        final int i = _cardsAnimationController.length - 1;
        _cardsAnimationController.last.addStatusListener(
          (AnimationStatus status) => deleteCardAnimated(i)(status),
        );
        _cardsAnimation.add(
          CurvedAnimation(
            parent: _cardsAnimationController.last,
            curve: animCurveEmphasizedDecelerate,
            reverseCurve: animCurveEmphasizedAccelerate,
          ),
        );
      }

      _registerCurrentSplitDraftListeners();

      // Individual for split transactions, show common for single transaction
      WidgetsBinding.instance.addPostFrameCallback((_) {
        updateTransactionAmounts();
        splitTransactionCheckAccounts();
      });

      if (_reconciled) {
        _initiallyReconciled = true;
      }

      _split = (_localAmounts.length > 1);
    } else {
      // New transaction
      _titleFocusNode.requestFocus();
      _transactionType = TransactionTypeProperty.swaggerGeneratedUnknown;

      if (widget.notification != null) {
        _date =
            _tzHandler.notificationTXTime(widget.notification!.date).toLocal();
      } else {
        _date = _tzHandler.newTXTime().toLocal();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        splitTransactionAdd();

        if (widget.templateSnapshot != null) {
          _applyEditorStateSnapshot(widget.templateSnapshot!);
        }

        // Extract notification
        if (widget.notification != null) {
          await _applyNotificationPrefill();
        }
        // Created from account screen, set account already
        if (widget.accountId != null && mounted) {
          // Check account
          final Response<AccountArray> response = await context
              .read<FireflyService>()
              .api
              .v1AccountsGet(type: AccountTypeFilter.assetAccount);
          if (!response.isSuccessful || response.body == null) {
            log.warning("api account fetch failed");
            return;
          }
          for (AccountRead acc in response.body!.data) {
            if (acc.id == widget.accountId) {
              _sourceAccountTextController.text = acc.attributes.name;
              _sourceAccountType = AccountTypeProperty.assetAccount;
              _ownAccountId = acc.id;
              checkTXType();
              break;
            }
          }
        }
        // Created from a file share to app
        if (widget.files != null && widget.files!.isNotEmpty) {
          await _prepareSharedAttachments(widget.files!);
        }
        if (_canUseDraftAutosave) {
          await _maybeRestoreDraftIfAvailable();
        }
      });
    }

    // If we're cloning, unset some values
    if (widget.clone) {
      _date = _tzHandler.newTXTime().toLocal();
      _reconciled = false;
      _initiallyReconciled = false;
      _transactionJournalIDs.forEachIndexed(
        (int i, _) => _transactionJournalIDs[i] = null,
      );
      _hasAttachments = false;
    }
  }

  bool get _canUseDraftAutosave =>
      _newTX &&
      widget.notification == null &&
      (widget.files?.isEmpty ?? true) &&
      widget.accountId == null &&
      !widget.clone &&
      widget.templateSnapshot == null;

  void _registerSharedDraftListeners() {
    _titleTextController.addListener(_scheduleDraftSave);
    _sourceAccountTextController.addListener(_scheduleDraftSave);
    _destinationAccountTextController.addListener(_scheduleDraftSave);
    _localAmountTextController.addListener(_scheduleDraftSave);
  }

  void _registerCurrentSplitDraftListeners() {
    for (final TextEditingController controller in <TextEditingController>[
      ..._categoryTextControllers,
      ..._budgetTextControllers,
      ..._tagsTextControllers,
      ..._noteTextControllers,
      ..._titleTextControllers,
      ..._sourceAccountTextControllers,
      ..._destinationAccountTextControllers,
      ..._localAmountTextControllers,
      ..._foreignAmountTextControllers,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
  }

  void _scheduleDraftSave() {
    if (!_canUseDraftAutosave || _savingInProgress) {
      return;
    }

    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_persistDraftIfEligible());
    });
  }

  TransactionEditorCurrencySnapshot? _toCurrencySnapshot(
    CurrencyRead? currency,
  ) {
    if (currency == null) {
      return null;
    }
    return TransactionEditorCurrencySnapshot(
      id: currency.id,
      code: currency.attributes.code,
      symbol: currency.attributes.symbol,
      decimalPlaces: currency.attributes.decimalPlaces,
    );
  }

  String _formatDraftAmount(double amount, int decimals) {
    if (amount == 0) {
      return '';
    }
    return amount.toStringAsFixed(decimals);
  }

  TransactionEditorStateSnapshot _captureEditorStateSnapshot() {
    final List<TransactionEditorSplitSnapshot> splits = List<
      TransactionEditorSplitSnapshot
    >.generate(_localAmounts.length, (int i) {
      final CurrencyRead? foreignCurrency = _foreignCurrencies[i];
      return TransactionEditorSplitSnapshot(
        title:
            _split ? _titleTextControllers[i].text : _titleTextController.text,
        sourceName:
            _sourceAccountTextControllers[i].text.isNotEmpty
                ? _sourceAccountTextControllers[i].text
                : _sourceAccountTextController.text,
        sourceType: _sourceAccountType,
        destinationName:
            _destinationAccountTextControllers[i].text.isNotEmpty
                ? _destinationAccountTextControllers[i].text
                : _destinationAccountTextController.text,
        destinationType: _destinationAccountType,
        localAmount: _localAmounts[i],
        foreignAmount: _foreignAmounts[i],
        foreignCurrency: _toCurrencySnapshot(foreignCurrency),
        categoryName: _categoryTextControllers[i].text,
        budgetName: _budgetTextControllers[i].text,
        notes: _noteTextControllers[i].text,
        tags: List<String>.from(_tags[i].tags),
        billId: _bills[i]?.id,
        billName: _bills[i]?.attributes.name,
        piggyBankId: _piggy[i]?.id,
        piggyBankName: _piggy[i]?.attributes.name,
      );
    });

    return TransactionEditorStateSnapshot(
      title: _titleTextController.text,
      ownAccountId: _ownAccountId,
      transactionType: _transactionType,
      date: _date,
      localCurrency: _toCurrencySnapshot(_localCurrency),
      reconciled: _reconciled,
      splitMode: _split,
      showSourceAccountSelection: _showSourceAccountSelection,
      showDestinationAccountSelection: _showDestinationAccountSelection,
      splits: splits,
    );
  }

  Future<void> _persistDraftIfEligible() async {
    if (!_canUseDraftAutosave) {
      return;
    }
    await _editorStateStore.saveDraft(_captureEditorStateSnapshot());
  }

  Future<void> _maybeRestoreDraftIfAvailable() async {
    final TransactionEditorDraftEnvelope? draft =
        await _editorStateStore.loadDraft();
    if (!mounted || draft == null || !draft.snapshot.hasMeaningfulData) {
      return;
    }

    final bool? shouldResume = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(Icons.history),
          title: Text(S.of(context).transactionDraftResumeTitle),
          clipBehavior: Clip.hardEdge,
          content: Text(S.of(context).transactionDraftResumeBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.of(context).transactionDraftDiscardAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(S.of(context).transactionDraftResumeAction),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }

    if (shouldResume ?? false) {
      setState(() {
        _applyEditorStateSnapshot(draft.snapshot);
      });
      return;
    }

    await _editorStateStore.clearDraft();
  }

  Future<void> _saveCurrentTemplate() async {
    final TransactionEditorStateSnapshot snapshot =
        _captureEditorStateSnapshot();
    if (!snapshot.hasMeaningfulData || !mounted) {
      return;
    }

    final String? templateName = await showTransactionTemplateNameDialog(
      context,
      initialName:
          _titleTextController.text.trim().isEmpty
              ? null
              : _titleTextController.text.trim(),
    );
    if (!mounted || templateName == null) {
      return;
    }

    final List<StoredTransactionEditorTemplate> templates =
        await _editorStateStore.loadTemplates();
    String? existingId;
    for (final StoredTransactionEditorTemplate template in templates) {
      if (template.name.toLowerCase() == templateName.toLowerCase()) {
        existingId = template.id;
        break;
      }
    }

    await _editorStateStore.saveTemplate(
      StoredTransactionEditorTemplate(
        id: existingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: templateName,
        snapshot: snapshot,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _applyTemplateFromPicker() async {
    final List<StoredTransactionEditorTemplate> templates =
        await _editorStateStore.loadTemplates();
    if (!mounted) {
      return;
    }

    final StoredTransactionEditorTemplate? template =
        await showTransactionTemplatePickerDialog(
          context,
          templates: templates,
        );
    if (!mounted || template == null) {
      return;
    }

    setState(() {
      _applyEditorStateSnapshot(template.snapshot);
    });
  }

  void _disposeSplitCollections() {
    for (final TextEditingController controller
        in _sourceAccountTextControllers) {
      controller.dispose();
    }
    for (final FocusNode focusNode in _sourceAccountFocusNodes) {
      focusNode.dispose();
    }
    for (final TextEditingController controller
        in _destinationAccountTextControllers) {
      controller.dispose();
    }
    for (final FocusNode focusNode in _destinationAccountFocusNodes) {
      focusNode.dispose();
    }
    for (final TextEditingController controller in _categoryTextControllers) {
      controller.dispose();
    }
    for (final FocusNode focusNode in _categoryFocusNodes) {
      focusNode.dispose();
    }
    for (final TextEditingController controller in _budgetTextControllers) {
      controller.dispose();
    }
    for (final FocusNode focusNode in _budgetFocusNodes) {
      focusNode.dispose();
    }
    for (final TextEditingController controller in _tagsTextControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller in _noteTextControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller in _titleTextControllers) {
      controller.dispose();
    }
    for (final FocusNode focusNode in _titleFocusNodes) {
      focusNode.dispose();
    }
    for (final TextEditingController controller
        in _localAmountTextControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _foreignAmountTextControllers) {
      controller.dispose();
    }
    for (final AnimationController controller in _cardsAnimationController) {
      controller.dispose();
    }

    _sourceAccountTextControllers.clear();
    _sourceAccountFocusNodes.clear();
    _destinationAccountTextControllers.clear();
    _destinationAccountFocusNodes.clear();
    _categoryTextControllers.clear();
    _categoryFocusNodes.clear();
    _budgetTextControllers.clear();
    _budgetFocusNodes.clear();
    _tags.clear();
    _tagsTextControllers.clear();
    _noteTextControllers.clear();
    _bills.clear();
    _piggy.clear();
    _titleTextControllers.clear();
    _titleFocusNodes.clear();
    _localAmounts.clear();
    _localAmountTextControllers.clear();
    _foreignAmounts.clear();
    _foreignAmountTextControllers.clear();
    _foreignCurrencies.clear();
    _transactionJournalIDs.clear();
    _deletedSplitIDs.clear();
    _cardsAnimationController.clear();
    _cardsAnimation.clear();
  }

  void _appendSplitFromSnapshot(TransactionEditorSplitSnapshot split) {
    final int localDecimals = _localCurrency?.attributes.decimalPlaces ?? 2;

    _categoryTextControllers.add(
      TextEditingController(text: split.categoryName),
    );
    _categoryFocusNodes.add(FocusNode());
    _budgetTextControllers.add(TextEditingController(text: split.budgetName));
    _budgetFocusNodes.add(FocusNode());
    _tags.add(Tags(List<String>.from(split.tags)));
    _tagsTextControllers.add(
      TextEditingController(text: split.tags.isNotEmpty ? " " : ""),
    );
    _noteTextControllers.add(TextEditingController(text: split.notes));
    _bills.add(
      (split.billId?.isNotEmpty ?? false)
          ? BillRead(
            type: 'bill',
            id: split.billId!,
            attributes: BillProperties(
              name: split.billName ?? '',
              amountMin: '0',
              amountMax: '0',
              date: DateTime.now(),
              repeatFreq: BillRepeatFrequency.swaggerGeneratedUnknown,
            ),
          )
          : null,
    );
    _piggy.add(
      (split.piggyBankId?.isNotEmpty ?? false)
          ? PiggyBankRead(
            id: split.piggyBankId!,
            type: 'piggy_banks',
            attributes: PiggyBankProperties(name: split.piggyBankName ?? ''),
            links: const ObjectLink(),
          )
          : null,
    );
    _titleTextControllers.add(TextEditingController(text: split.title));
    _titleFocusNodes.add(FocusNode());
    _sourceAccountTextControllers.add(
      TextEditingController(text: split.sourceName),
    );
    _sourceAccountFocusNodes.add(FocusNode());
    _destinationAccountTextControllers.add(
      TextEditingController(text: split.destinationName),
    );
    _destinationAccountFocusNodes.add(FocusNode());
    _localAmounts.add(split.localAmount);
    _localAmountTextControllers.add(
      TextEditingController(
        text: _formatDraftAmount(split.localAmount, localDecimals),
      ),
    );
    _foreignAmounts.add(split.foreignAmount);
    _foreignCurrencies.add(split.foreignCurrency?.toCurrencyRead());
    _foreignAmountTextControllers.add(
      TextEditingController(
        text: _formatDraftAmount(
          split.foreignAmount,
          split.foreignCurrency?.decimalPlaces ?? localDecimals,
        ),
      ),
    );
    _transactionJournalIDs.add(null);
    _cardsAnimationController.add(
      AnimationController(
        value: 1.0,
        duration: animDurationEmphasizedDecelerate,
        reverseDuration: animDurationEmphasizedDecelerate,
        vsync: this,
      ),
    );
    final int index = _cardsAnimationController.length - 1;
    _cardsAnimationController.last.addStatusListener(
      (AnimationStatus status) => deleteCardAnimated(index)(status),
    );
    _cardsAnimation.add(
      CurvedAnimation(
        parent: _cardsAnimationController.last,
        curve: animCurveEmphasizedDecelerate,
        reverseCurve: animCurveEmphasizedAccelerate,
      ),
    );
  }

  void _applyEditorStateSnapshot(TransactionEditorStateSnapshot snapshot) {
    _titleTextController.text = snapshot.title;
    _ownAccountId = snapshot.ownAccountId;
    _transactionType = snapshot.transactionType;
    _date = tz.TZDateTime.from(snapshot.date, _date.location);
    _localCurrency = snapshot.localCurrency?.toCurrencyRead() ?? _localCurrency;
    _reconciled = snapshot.reconciled;
    _initiallyReconciled = false;
    _showSourceAccountSelection = snapshot.showSourceAccountSelection;
    _showDestinationAccountSelection = snapshot.showDestinationAccountSelection;
    _hasAttachments = false;
    _attachments = null;
    _managedSharedAttachmentPaths.clear();
    _managedSharedAttachmentRoots = <String>[];
    _attachmentLoadRequested = false;
    _disposeSplitCollections();

    final List<TransactionEditorSplitSnapshot> splits =
        snapshot.splits.isEmpty
            ? const <TransactionEditorSplitSnapshot>[
              TransactionEditorSplitSnapshot(
                title: '',
                sourceName: '',
                sourceType: AccountTypeProperty.swaggerGeneratedUnknown,
                destinationName: '',
                destinationType: AccountTypeProperty.swaggerGeneratedUnknown,
                localAmount: 0,
                foreignAmount: 0,
                foreignCurrency: null,
                categoryName: '',
                budgetName: '',
                notes: '',
                tags: <String>[],
                billId: null,
                billName: null,
                piggyBankId: null,
                piggyBankName: null,
              ),
            ]
            : snapshot.splits;
    for (final TransactionEditorSplitSnapshot split in splits) {
      _appendSplitFromSnapshot(split);
    }
    _registerCurrentSplitDraftListeners();

    final TransactionEditorSplitSnapshot firstSplit = splits.first;
    _sourceAccountTextController.text = firstSplit.sourceName;
    _destinationAccountTextController.text = firstSplit.destinationName;
    _sourceAccountType = firstSplit.sourceType;
    _destinationAccountType = firstSplit.destinationType;
    _localAmountTextController.text = _formatDraftAmount(
      firstSplit.localAmount,
      _localCurrency?.attributes.decimalPlaces ?? 2,
    );
    _split = snapshot.splitMode || splits.length > 1;

    updateTransactionAmounts();
    splitTransactionCheckAccounts();
    checkTXType();
    _scheduleDraftSave();
  }

  Future<void> _prepareSharedAttachments(List<SharedFile> files) async {
    final List<String> managedRoots =
        await resolveManagedSharedAttachmentRoots();
    final SharedAttachmentValidationResult result =
        await validateSharedAttachments(files, appOwnedRoots: managedRoots);
    if (!mounted || !result.hasAny) {
      return;
    }

    log.info(
      () =>
          'shared attachment review: ${result.accepted.length} accepted, ${result.rejected.length} rejected',
    );

    final SharedAttachmentReviewAction? action =
        await showDialog<SharedAttachmentReviewAction>(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext context) =>
                  SharedAttachmentReviewDialog(result: result),
        );
    if (!mounted) {
      return;
    }

    if (action == SharedAttachmentReviewAction.accept) {
      setState(() {
        _attachments ??= <AttachmentRead>[];
        _managedSharedAttachmentRoots = managedRoots;
        for (final SharedAttachmentCandidate candidate in result.accepted) {
          _attachments!.add(
            sharedAttachmentToDraft(candidate, _attachments!.length),
          );
          if (candidate.isAppOwnedCopy) {
            _managedSharedAttachmentPaths.add(candidate.path);
          }
        }
        _hasAttachments = _attachments?.isNotEmpty ?? false;
      });
      return;
    }

    for (final SharedAttachmentCandidate candidate in result.accepted) {
      await deleteSharedAttachmentIfOwnedCopy(candidate.path, managedRoots);
    }
  }

  Future<void> _cleanupManagedSharedAttachments() async {
    if (_managedSharedAttachmentPaths.isEmpty) {
      return;
    }

    final List<String> paths = _managedSharedAttachmentPaths.toList();
    _managedSharedAttachmentPaths.clear();
    await cleanupManagedSharedAttachments(paths, _managedSharedAttachmentRoots);
  }

  List<TransactionEditorSplitDraft> _buildSplitDrafts({
    required bool trimDate,
  }) {
    return List<TransactionEditorSplitDraft>.generate(_localAmounts.length, (
      int i,
    ) {
      String sourceName = _sourceAccountTextControllers[i].text;
      if (sourceName.isEmpty) {
        sourceName = _sourceAccountTextController.text;
      }

      String destinationName = _destinationAccountTextControllers[i].text;
      if (destinationName.isEmpty) {
        destinationName = _destinationAccountTextController.text;
      }

      return TransactionEditorSplitDraft(
        amount: _localAmounts[i],
        billId: _bills[i]?.id ?? "0",
        budgetName:
            (_transactionType == TransactionTypeProperty.withdrawal)
                ? _budgetTextControllers[i].text
                : "",
        categoryName: _categoryTextControllers[i].text,
        date:
            trimDate
                ? _date.copyWith(second: 0, millisecond: 0, microsecond: 0)
                : _date,
        description:
            _split ? _titleTextControllers[i].text : _titleTextController.text,
        destinationName: destinationName,
        foreignAmount: _foreignCurrencies[i] != null ? _foreignAmounts[i] : 0,
        foreignCurrencyId: _foreignCurrencies[i]?.id,
        notes: _noteTextControllers[i].text,
        order: i,
        piggyBankId: (_piggy[i]?.id != null) ? int.parse(_piggy[i]!.id) : null,
        reconciled: _reconciled,
        sourceName: sourceName,
        tags: _tags[i].tags,
        transactionJournalId: _transactionJournalIDs.elementAtOrNull(i),
        type: _transactionType,
      );
    });
  }

  Future<void> _applyNotificationPrefill() async {
    final FireflyIii api = context.read<FireflyService>().api;
    final SettingsProvider settings = context.read<SettingsProvider>();
    final CurrencyRead defaultCurrency =
        context.read<FireflyService>().defaultCurrency;
    _localCurrency ??= defaultCurrency;

    final TransactionNotificationPrefillDraft? prefill =
        await TransactionNotificationPrefillAdapter.build(
          api: api,
          settings: settings,
          notification: widget.notification!,
          initialLocalCurrency: _localCurrency!,
          defaultCurrency: defaultCurrency,
        );
    if (!mounted || prefill == null) {
      return;
    }

    log.info("Got notification payload for transaction creation");
    _transactionType = prefill.type;
    _titleTextController.text = prefill.title;
    _noteTextControllers[0].text = prefill.note;
    _sourceAccountTextController.text = prefill.sourceAccountName;
    _sourceAccountType = prefill.sourceAccountType;
    _ownAccountId = prefill.ownAccountId;
    _localCurrency = prefill.localCurrency;
    _localAmounts[0] = prefill.localAmount;
    _foreignCurrencies[0] = prefill.foreignCurrency;
    _foreignAmounts[0] = prefill.foreignAmount;

    _localAmountTextController.text =
        prefill.localAmount > 0
            ? prefill.localAmount.toStringAsFixed(
              _localCurrency?.attributes.decimalPlaces ?? 2,
            )
            : "";
    _foreignAmountTextControllers[0].text =
        prefill.foreignCurrency != null
            ? prefill.foreignAmount.toStringAsFixed(
              prefill.foreignCurrency!.attributes.decimalPlaces ?? 2,
            )
            : "";

    setState(() {
      checkTXType();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_persistDraftIfEligible());
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftSaveDebounce?.cancel();
    if (_canUseDraftAutosave) {
      if (_clearDraftOnDispose) {
        unawaited(_editorStateStore.clearDraft());
      } else {
        unawaited(_persistDraftIfEligible());
      }
    }
    unawaited(_cleanupManagedSharedAttachments());
    _titleTextController.dispose();
    _titleFocusNode.dispose();
    _sourceAccountTextController.dispose();
    _sourceAccountFocusNode.dispose();
    _destinationAccountTextController.dispose();
    _destinationAccountFocusNode.dispose();
    _localAmountTextController.dispose();

    _disposeSplitCollections();

    super.dispose();
  }

  void updateTransactionAmounts() {
    // Individual for split transactions, show common for single transaction
    /// local amount
    if (_localAmounts.sum != 0) {
      _localAmountTextController.text = _localAmounts.sum.toStringAsFixed(
        _localCurrency?.attributes.decimalPlaces ?? 2,
      );
    } else {
      _localAmountTextController.text = "";
    }
  }

  void Function(AnimationStatus) deleteCardAnimated(int i) {
    return (AnimationStatus status) {
      if (status == AnimationStatus.dismissed) {
        splitTransactionRemove(i);
      }
    };
  }

  void splitTransactionRemove(int i) {
    log.fine(() => "removing split $i");
    if (_localAmounts.length < i || _localAmounts.length == 1) {
      log.finer(() => "can't remove, last item");
      return;
    }

    // this we need to dispose later
    final TextEditingController t1 = _sourceAccountTextControllers.removeAt(i);
    final FocusNode f1 = _sourceAccountFocusNodes.removeAt(i);
    final TextEditingController t2 = _destinationAccountTextControllers
        .removeAt(i);
    final FocusNode f2 = _destinationAccountFocusNodes.removeAt(i);
    final TextEditingController t3 = _categoryTextControllers.removeAt(i);
    final FocusNode f3 = _categoryFocusNodes.removeAt(i);
    final TextEditingController t4 = _budgetTextControllers.removeAt(i);
    final FocusNode f4 = _budgetFocusNodes.removeAt(i);
    _tags.removeAt(i);
    final TextEditingController t5 = _tagsTextControllers.removeAt(i);
    final TextEditingController t6 = _noteTextControllers.removeAt(i);
    _bills.removeAt(i);
    _piggy.removeAt(i);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      t1.dispose();
      f1.dispose();
      t2.dispose();
      f2.dispose();
      t3.dispose();
      f3.dispose();
      t4.dispose();
      f4.dispose();
      t5.dispose();
      t6.dispose();
    });

    _titleTextControllers.removeAt(i).dispose();
    _titleFocusNodes.removeAt(i).dispose();
    _localAmounts.removeAt(i);
    _localAmountTextControllers.removeAt(i).dispose();
    _foreignAmounts.removeAt(i);
    _foreignAmountTextControllers.removeAt(i).dispose();
    _foreignCurrencies.removeAt(i);
    _deletedSplitIDs.add(_transactionJournalIDs.elementAtOrNull(i) ?? "");
    _transactionJournalIDs.removeAt(i);

    _cardsAnimationController.removeAt(i).dispose();
    _cardsAnimation.removeAt(i);

    // Update summary values
    updateTransactionAmounts();
    if (_localAmounts.length == 1) {
      // This is similar to the web interface --> summary text gets deleted when split is removed.
      if (_titleTextControllers.first.text.isNotEmpty) {
        _titleTextController.text = _titleTextControllers.first.text;
      }
    }
    // Check if Source/Destination account selection should still be shown
    if (_sourceAccountTextControllers.every(
      (TextEditingController e) =>
          e.text == _sourceAccountTextControllers.first.text,
    )) {
      _showSourceAccountSelection = false;
    }
    if (_destinationAccountTextControllers.every(
      (TextEditingController e) =>
          e.text == _destinationAccountTextControllers.first.text,
    )) {
      _showDestinationAccountSelection = false;
    }
    splitTransactionCheckAccounts();

    // Redo animationcallbacks due to new "i"s
    for (int i = 0; i < _cardsAnimationController.length; i++) {
      // ignore: invalid_use_of_protected_member
      _cardsAnimationController[i].clearStatusListeners();
      _cardsAnimationController[i].addStatusListener(
        (AnimationStatus status) => deleteCardAnimated(i)(status),
      );
    }

    log.finer(() => "remaining split #: ${_localAmounts.length}");

    setState(() {
      // As firefly doesn't allow editing accounts or sums when reconciled,
      // deactivate reconciled.
      _initiallyReconciled = false;
      _split = (_localAmounts.length > 1);
    });
    _scheduleDraftSave();
  }

  void splitTransactionAdd() {
    log.fine(() => "adding split");
    // Update from summary to first when first split is added
    if (_localAmounts.length == 1) {
      _localAmountTextControllers.first.text = _localAmountTextController.text;
    }

    _sourceAccountTextControllers.add(
      TextEditingController(
        text: _sourceAccountTextControllers.firstOrNull?.text,
      ),
    );
    _sourceAccountTextControllers.last.addListener(_scheduleDraftSave);
    _sourceAccountFocusNodes.add(FocusNode());
    _destinationAccountTextControllers.add(
      TextEditingController(
        text: _destinationAccountTextControllers.firstOrNull?.text,
      ),
    );
    _destinationAccountTextControllers.last.addListener(_scheduleDraftSave);
    _destinationAccountFocusNodes.add(FocusNode());
    _categoryTextControllers.add(TextEditingController());
    _categoryTextControllers.last.addListener(_scheduleDraftSave);
    _categoryFocusNodes.add(FocusNode());
    _budgetTextControllers.add(TextEditingController());
    _budgetTextControllers.last.addListener(_scheduleDraftSave);
    _budgetFocusNodes.add(FocusNode());
    _tags.add(Tags());
    _tagsTextControllers.add(TextEditingController());
    _tagsTextControllers.last.addListener(_scheduleDraftSave);
    _noteTextControllers.add(TextEditingController());
    _noteTextControllers.last.addListener(_scheduleDraftSave);
    _bills.add(null);
    _piggy.add(null);

    _titleTextControllers.add(TextEditingController());
    _titleTextControllers.last.addListener(_scheduleDraftSave);
    _titleFocusNodes.add(FocusNode());
    _localAmounts.add(0);
    _localAmountTextControllers.add(TextEditingController());
    _localAmountTextControllers.last.addListener(_scheduleDraftSave);
    _foreignAmounts.add(0);
    _foreignAmountTextControllers.add(TextEditingController());
    _foreignAmountTextControllers.last.addListener(_scheduleDraftSave);
    _foreignCurrencies.add(_foreignCurrencies.firstOrNull);
    _transactionJournalIDs.add(null);

    _cardsAnimationController.add(
      AnimationController(
        // height 0 = invisible - enter = fwd (0->1), exit = reverse (1->0)
        value: 0.0,
        duration: animDurationEmphasizedDecelerate,
        reverseDuration: animDurationEmphasizedAccelerate,
        vsync: this,
      ),
    );
    final int i = _cardsAnimationController.length - 1;
    _cardsAnimationController.last.addStatusListener(
      (AnimationStatus status) => deleteCardAnimated(i)(status),
    );
    _cardsAnimation.add(
      CurvedAnimation(
        parent: _cardsAnimationController.last,
        curve: animCurveEmphasizedDecelerate,
        reverseCurve: animCurveEmphasizedAccelerate,
      ),
    );

    log.finer(() => "new split #: ${_localAmounts.length}");

    setState(() {
      // As firefly doesn't allow editing accounts or sums when reconciled,
      // deactivate reconciled.
      _initiallyReconciled = false;
      _split = (_localAmounts.length > 1);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cardsAnimationController.last.forward();
    });
    _scheduleDraftSave();
  }

  void splitTransactionCalculateAmount() {
    _localAmountTextController.text = _localAmounts.sum.toStringAsFixed(
      _localCurrency?.attributes.decimalPlaces ?? 2,
    );
  }

  void _ensureAttachmentCountLoaded() {
    if (_attachmentLoadRequested || !_hasAttachments || _attachments != null) {
      return;
    }

    _attachmentLoadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await updateAttachmentCount();
      } finally {
        _attachmentLoadRequested = false;
      }
    });
  }

  List<String> _validationMessages(BuildContext context) {
    final S l10n = S.of(context);
    final List<String> messages = <String>[];
    if (_titleTextController.text.isEmpty) {
      messages.add(l10n.transactionSectionAttentionMissingTitle);
    }
    if (_transactionType == TransactionTypeProperty.swaggerGeneratedUnknown) {
      messages.add(l10n.transactionSectionAttentionMissingAccounts);
    }
    if (_ownAccountId == null) {
      messages.add(l10n.transactionSectionAttentionMissingOwnAccount);
    }
    return messages;
  }

  List<Widget> _buildOverviewChips(BuildContext context) {
    final S l10n = S.of(context);
    final List<Widget> chips = <Widget>[];

    if (_transactionType != TransactionTypeProperty.swaggerGeneratedUnknown) {
      chips.add(
        Chip(
          avatar: Icon(
            _transactionType.verticalIcon,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          label: Text(_transactionType.friendlyName(context)),
        ),
      );
    }

    chips.add(
      Chip(
        avatar: const Icon(Icons.call_split),
        label: Text(
          l10n.transactionSectionSplitsSubtitle(_localAmounts.length),
        ),
      ),
    );

    if (_localCurrency != null) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.monetization_on_outlined),
          label: Text(_localCurrency!.attributes.code),
        ),
      );
    }

    chips.add(
      Chip(
        avatar: const Icon(Icons.attach_file),
        label: Text(
          '${l10n.transactionAttachments}: ${_attachments?.length ?? (_hasAttachments ? "..." : "0")}',
        ),
      ),
    );

    return chips;
  }

  void splitTransactionCheckAccounts() {
    bool update = false;

    if (_sourceAccountTextControllers.every(
      (TextEditingController e) =>
          e.text == _sourceAccountTextControllers.first.text,
    )) {
      if (_sourceAccountTextController.text !=
              _sourceAccountTextControllers.first.text &&
          _sourceAccountTextControllers.first.text.isNotEmpty) {
        _sourceAccountTextController.text =
            _sourceAccountTextControllers.first.text;
        update = true;
      }
    } else {
      if (_sourceAccountTextController.text !=
          "<${S.of(context).generalMultiple}>") {
        _sourceAccountTextController.text =
            "<${S.of(context).generalMultiple}>";
        update = true;
      }
    }
    if (_destinationAccountTextControllers.every(
      (TextEditingController e) =>
          e.text == _destinationAccountTextControllers.first.text,
    )) {
      if (_destinationAccountTextController.text !=
              _destinationAccountTextControllers.first.text &&
          _destinationAccountTextControllers.first.text.isNotEmpty) {
        _destinationAccountTextController.text =
            _destinationAccountTextControllers.first.text;
        update = true;
      }
    } else {
      if (_destinationAccountTextController.text !=
          "<${S.of(context).generalMultiple}>") {
        _destinationAccountTextController.text =
            "<${S.of(context).generalMultiple}>";
        update = true;
      }
    }

    // Withdrawal: splits have common source account --> show only target
    // Deposit: splits have common destination account --> show only source
    // Transfer: splits have common accounts for both --> show nothing
    final bool prevShowSource = _showSourceAccountSelection;
    final bool prevShowDest = _showDestinationAccountSelection;
    _showSourceAccountSelection =
        _transactionType == TransactionTypeProperty.deposit &&
        _sourceAccountTextControllers.every(
          (TextEditingController e) =>
              e.text != _sourceAccountTextController.text,
        );
    _showDestinationAccountSelection =
        _transactionType == TransactionTypeProperty.withdrawal &&
        _destinationAccountTextControllers.every(
          (TextEditingController e) =>
              e.text != _destinationAccountTextController.text,
        );
    if (prevShowSource != _showSourceAccountSelection ||
        prevShowDest != _showDestinationAccountSelection) {
      update = true;
    }

    if (update) {
      setState(() {});
    }
  }

  Future<void> updateAttachmentCount() async {
    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final Response<AttachmentArray> response = await api
          .v1TransactionsIdAttachmentsGet(id: widget.transaction?.id);
      apiThrowErrorIfEmpty(response, mounted ? context : null);

      if (!mounted) {
        return;
      }
      _attachments = response.body!.data;
      setState(() {
        _hasAttachments = _attachments?.isNotEmpty ?? false;
      });
    } catch (e, stackTrace) {
      log.severe("Error while fetching autocomplete from API", e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");
    _localCurrency ??= context.read<FireflyService>().defaultCurrency;

    _ensureAttachmentCountLoaded();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _newTX
              ? S.of(context).transactionTitleAdd
              : S.of(context).transactionTitleEdit,
        ),
        actions: <Widget>[
          PopupMenuButton<_TransactionToolbarAction>(
            onSelected: (_TransactionToolbarAction action) async {
              switch (action) {
                case _TransactionToolbarAction.useTemplate:
                  await _applyTemplateFromPicker();
                  break;
                case _TransactionToolbarAction.saveTemplate:
                  await _saveCurrentTemplate();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<_TransactionToolbarAction>>[
                if (_newTX)
                  PopupMenuItem<_TransactionToolbarAction>(
                    value: _TransactionToolbarAction.useTemplate,
                    child: Text(S.of(context).transactionTemplateApplyAction),
                  ),
                PopupMenuItem<_TransactionToolbarAction>(
                  value: _TransactionToolbarAction.saveTemplate,
                  child: Text(S.of(context).transactionTemplateSaveAction),
                ),
              ];
            },
          ),
          if (!_newTX) ...<Widget>[
            TransactionDeleteButton(
              transactionId: widget.transaction?.id,
              disabled: _savingInProgress,
            ),
            const SizedBox(width: 8),
          ],
          FilledButton(
            onPressed:
                _savingInProgress
                    ? null
                    : () async {
                      final ScaffoldMessengerState msg = ScaffoldMessenger.of(
                        context,
                      );
                      final NavigatorState nav = Navigator.of(context);
                      final FireflyIii api = context.read<FireflyService>().api;
                      final AuthUser? user =
                          context.read<FireflyService>().user;
                      final TransStock? stock =
                          context.read<FireflyService>().transStock;

                      // Sanity checks
                      String? error;

                      if (_ownAccountId == null) {
                        error = S.of(context).transactionErrorNoAssetAccount;
                      }
                      if (_titleTextController.text.isEmpty) {
                        error = S.of(context).transactionErrorTitle;
                      }
                      if (user == null || stock == null) {
                        error = S.of(context).errorAPIUnavailable;
                      }
                      if (_transactionType ==
                          TransactionTypeProperty.swaggerGeneratedUnknown) {
                        error = S.of(context).transactionErrorNoAccounts;
                      }
                      if (error != null) {
                        msg.showSnackBar(
                          SnackBar(
                            content: Text(error),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      // Do stuff
                      setState(() {
                        _savingInProgress = true;
                      });
                      late Response<TransactionSingle> resp;
                      final List<TransactionEditorSplitDraft> drafts =
                          _buildSplitDrafts(trimDate: _newTX);

                      // Update existing transaction
                      if (!_newTX) {
                        final String id = widget.transaction!.id;
                        final TransactionUpdate txUpdate =
                            TransactionEditorPayloadMapper.buildUpdate(
                              drafts: drafts,
                              existingSplits:
                                  widget.transaction?.attributes.transactions ??
                                  const <TransactionSplit>[],
                              groupTitle:
                                  _split ? _titleTextController.text : null,
                            );
                        // Delete old splits
                        final List<Future<Response<dynamic>>> futures =
                            _deletedSplitIDs
                                .where((String id) => id.isNotEmpty)
                                .map((String id) {
                                  log.fine(() => "deleting split $id");
                                  return api.v1TransactionJournalsIdDelete(
                                    id: id,
                                  );
                                })
                                .toList();
                        if (futures.isNotEmpty) {
                          await Future.wait(futures);
                        }
                        resp = await api.v1TransactionsIdPut(
                          id: id,
                          body: txUpdate,
                        );
                      } else {
                        // New transaction
                        final TransactionStore newTx =
                            TransactionEditorPayloadMapper.buildStore(
                              drafts: drafts,
                              groupTitle:
                                  _split ? _titleTextController.text : null,
                            );
                        resp = await api.v1TransactionsPost(body: newTx);
                      }

                      // Check if insert/update was successful
                      if (!resp.isSuccessful || resp.body == null) {
                        try {
                          final ValidationErrorResponse valError =
                              ValidationErrorResponse.fromJson(
                                json.decode(resp.error.toString()),
                              );
                          error =
                              valError.message ??
                              // ignore: use_build_context_synchronously
                              (context.mounted
                                  // ignore: use_build_context_synchronously
                                  ? S.of(context).errorUnknown
                                  : "[nocontext] Unknown error.");
                        } catch (_) {
                          // ignore: use_build_context_synchronously
                          error =
                              context.mounted
                                  // ignore: use_build_context_synchronously
                                  ? S.of(context).errorUnknown
                                  : "[nocontext] Unknown error.";
                        }

                        msg.showSnackBar(
                          SnackBar(
                            content: Text(error),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        setState(() {
                          _savingInProgress = false;
                        });
                        return;
                      }

                      // Update stock
                      await stock!.setTransaction(resp.body!.data);

                      // Upload attachments if required
                      if (_attachments?.isNotEmpty ?? false) {
                        await TransactionAttachmentUploadService(
                          api: api,
                          user: user!,
                          logger: log,
                        ).uploadDraftAttachments(
                          attachments: _attachments!,
                          transaction: resp.body!,
                          transactionJournalIds: _transactionJournalIDs,
                        );
                      }

                      // Done saving
                      _clearDraftOnDispose = true;
                      await _editorStateStore.clearDraft();
                      setState(() => _savingInProgress = false);

                      if (nav.canPop()) {
                        // Popping true means that the TX list will be refreshed.
                        // This should only happen if:
                        // 1. it is a new transaction
                        // 2. the date has been changed (changing the order of the TX list)
                        nav.pop(
                          widget.transaction == null ||
                              _date !=
                                  _tzHandler.sTime(
                                    widget
                                        .transaction!
                                        .attributes
                                        .transactions
                                        .first
                                        .date,
                                  ),
                        );
                      } else {
                        // Launched from notification
                        // https://stackoverflow.com/questions/45109557/flutter-how-to-programmatically-exit-the-app
                        await SystemChannels.platform.invokeMethod(
                          'SystemNavigator.pop',
                        );
                        await nav.pushReplacement(
                          MaterialPageRoute<bool>(
                            builder: (BuildContext context) => const NavPage(),
                          ),
                        );
                      }
                    },
            child:
                _savingInProgress
                    ? const SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                    : Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: PopScope(
        canPop: !_savingInProgress,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            cacheExtent: 10000,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: _transactionDetailBuilder(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _transactionDetailBuilder(BuildContext context) {
    log.fine(() => "transactionDetailBuilder()");
    log.finer(() => "splits: ${_localAmounts.length}, split? $_split");

    final List<Widget> childs = <Widget>[];
    const Widget hDivider = SizedBox(height: 20);
    const Widget vDivider = SizedBox(width: 16);

    CancelableOperation<Response<AutocompleteAccountArray>>? fetchOpSource;
    CancelableOperation<Response<AutocompleteAccountArray>>? fetchOpDestination;
    final S l10n = S.of(context);
    final List<String> validationMessages = _validationMessages(context);

    if (validationMessages.isNotEmpty) {
      childs.add(
        _TransactionEditorValidationCard(messages: validationMessages),
      );
      childs.add(hDivider);
    }

    childs.add(
      TransactionSectionCard(
        title: l10n.transactionSectionOverview,
        subtitle: l10n.transactionSectionOverviewSubtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TransactionTitle(
                    textController: _titleTextController,
                    focusNode: _titleFocusNode,
                    disabled: _savingInProgress,
                  ),
                ),
                const SizedBox(width: 12),
                AttachmentButton(
                  attachments: _attachments,
                  disabled: _savingInProgress,
                  onPressed: () async {
                    final List<AttachmentRead> dialogAttachments =
                        _attachments ?? <AttachmentRead>[];
                    await showDialog<List<AttachmentRead>>(
                      context: context,
                      builder:
                          (BuildContext context) => AttachmentDialog(
                            attachments: dialogAttachments,
                            transactionId: _transactionJournalIDs
                                .firstWhereOrNull(
                                  (String? element) => element != null,
                                ),
                          ),
                    );
                    setState(() {
                      _attachments = dialogAttachments;
                      _hasAttachments = _attachments?.isNotEmpty ?? false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildOverviewChips(context),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: NumberInput(
                    icon:
                        _localCurrency != null
                            ? SizedBox(
                              width: 24,
                              height: 32,
                              child: FittedBox(
                                child: Text(_localCurrency!.attributes.symbol),
                              ),
                            )
                            : const Icon(Icons.monetization_on),
                    hintText:
                        _localCurrency?.zero() ??
                        NumberFormat.currency(decimalDigits: 2).format(0),
                    decimals: _localCurrency?.attributes.decimalPlaces ?? 2,
                    controller: _localAmountTextController,
                    disabled:
                        _savingInProgress ||
                        _split ||
                        (_reconciled && _initiallyReconciled),
                    onChanged:
                        (String string) =>
                            _localAmounts[0] = double.tryParse(string) ?? 0,
                  ),
                ),
                DateTimePicker(
                  initialDateTime: _date,
                  disabled: _savingInProgress,
                  onDateTimeChanged: (tz.TZDateTime newDateTime) {
                    setState(() {
                      _date = newDateTime;
                    });
                    _scheduleDraftSave();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
    childs.add(hDivider);

    childs.add(
      TransactionSectionCard(
        title: l10n.transactionSectionAccounts,
        subtitle: l10n.transactionSectionAccountsSubtitle,
        child: Stack(
          children: <Widget>[
            const SizedBox(height: 64 + 16 + 64),
            Row(
              children: <Widget>[
                const Icon(Icons.logout),
                vDivider,
                Expanded(
                  child: AutoCompleteText<AutocompleteAccount>(
                    labelText: l10n.generalSourceAccount,
                    textController: _sourceAccountTextController,
                    focusNode: _sourceAccountFocusNode,
                    errorIconOnly: true,
                    onChanged: (String val) {
                      for (TextEditingController e
                          in _sourceAccountTextControllers) {
                        e.text = val;
                      }

                      if (_sourceAccountType ==
                              AccountTypeProperty.assetAccount ||
                          _sourceAccountType == AccountTypeProperty.debt) {
                        _ownAccountId = null;
                      }
                      _sourceAccountType =
                          AccountTypeProperty.swaggerGeneratedUnknown;
                      checkTXType();
                    },
                    onSelected: (AutocompleteAccount option) {
                      for (TextEditingController e
                          in _sourceAccountTextControllers) {
                        e.text = option.name;
                      }
                      _sourceAccountType = AccountTypeProperty.values
                          .firstWhere(
                            (AccountTypeProperty e) => e.value == option.type,
                            orElse:
                                () =>
                                    AccountTypeProperty.swaggerGeneratedUnknown,
                          );
                      log.finer(
                        () =>
                            "selected source account ${option.name}, type ${_sourceAccountType.toString()} (${option.type})",
                      );
                      if (_sourceAccountType ==
                              AccountTypeProperty.assetAccount ||
                          _sourceAccountType == AccountTypeProperty.debt) {
                        _ownAccountId = option.id;
                      }
                      checkTXType();
                      checkAccountCurrency(option, true);
                    },
                    displayStringForOption:
                        (AutocompleteAccount option) => option.name,
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      try {
                        unawaited(fetchOpSource?.cancel());

                        final FireflyIii api =
                            context.read<FireflyService>().api;
                        fetchOpSource = CancelableOperation<
                          Response<AutocompleteAccountArray>
                        >.fromFuture(
                          api.v1AutocompleteAccountsGet(
                            query: textEditingValue.text,
                            types: _destinationAccountType.allowedOpposingTypes(
                              false,
                            ),
                          ),
                        );
                        final Response<AutocompleteAccountArray>? response =
                            await fetchOpSource?.valueOrCancellation();
                        if (response == null) {
                          return const Iterable<AutocompleteAccount>.empty();
                        }
                        apiThrowErrorIfEmpty(
                          response,
                          mounted ? context : null,
                        );

                        return response.body!;
                      } catch (e, stackTrace) {
                        log.severe(
                          "Error while fetching autocomplete from API",
                          e,
                          stackTrace,
                        );
                        return const Iterable<AutocompleteAccount>.empty();
                      }
                    },
                    disabled:
                        _savingInProgress ||
                        (_reconciled && _initiallyReconciled) ||
                        _sourceAccountTextController.text ==
                            "<${l10n.generalMultiple}>",
                  ),
                ),
              ],
            ),
            Positioned.fill(
              top: 64 + 16,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.login),
                  vDivider,
                  Expanded(
                    child: AutoCompleteText<AutocompleteAccount>(
                      labelText: l10n.generalDestinationAccount,
                      textController: _destinationAccountTextController,
                      focusNode: _destinationAccountFocusNode,
                      onChanged: (String val) {
                        for (TextEditingController e
                            in _destinationAccountTextControllers) {
                          e.text = val;
                        }

                        if (_destinationAccountType ==
                                AccountTypeProperty.assetAccount ||
                            _destinationAccountType ==
                                AccountTypeProperty.debt) {
                          _ownAccountId = null;
                        }
                        _destinationAccountType =
                            AccountTypeProperty.swaggerGeneratedUnknown;
                        checkTXType();
                      },
                      errorIconOnly: true,
                      displayStringForOption:
                          (AutocompleteAccount option) => option.name,
                      onSelected: (AutocompleteAccount option) {
                        for (TextEditingController e
                            in _destinationAccountTextControllers) {
                          e.text = option.name;
                        }
                        _destinationAccountType = AccountTypeProperty.values
                            .firstWhere(
                              (AccountTypeProperty e) => e.value == option.type,
                              orElse:
                                  () =>
                                      AccountTypeProperty
                                          .swaggerGeneratedUnknown,
                            );
                        if (_destinationAccountType ==
                                AccountTypeProperty.assetAccount ||
                            _destinationAccountType ==
                                AccountTypeProperty.debt) {
                          _ownAccountId = option.id;
                        }
                        log.finer(
                          () =>
                              "selected destination account ${option.name}, type ${_destinationAccountType.toString()} (${option.type})",
                        );
                        checkTXType();
                        checkAccountCurrency(option, false);
                      },
                      optionsBuilder: (
                        TextEditingValue textEditingValue,
                      ) async {
                        try {
                          unawaited(fetchOpDestination?.cancel());

                          final FireflyIii api =
                              context.read<FireflyService>().api;
                          fetchOpDestination = CancelableOperation<
                            Response<AutocompleteAccountArray>
                          >.fromFuture(
                            api.v1AutocompleteAccountsGet(
                              query: textEditingValue.text,
                              types: _sourceAccountType.allowedOpposingTypes(
                                true,
                              ),
                            ),
                          );
                          final Response<AutocompleteAccountArray>? response =
                              await fetchOpDestination?.valueOrCancellation();
                          if (response == null) {
                            return const Iterable<AutocompleteAccount>.empty();
                          }
                          apiThrowErrorIfEmpty(
                            response,
                            mounted ? context : null,
                          );

                          return response.body!;
                        } catch (e, stackTrace) {
                          log.severe(
                            "Error while fetching autocomplete from API",
                            e,
                            stackTrace,
                          );
                          return const Iterable<AutocompleteAccount>.empty();
                        }
                      },
                      disabled:
                          _savingInProgress ||
                          (_reconciled && _initiallyReconciled) ||
                          _destinationAccountTextController.text ==
                              "<${l10n.generalMultiple}>",
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: (64 + 16 + 4) / 2,
              right: 15,
              child: FloatingActionButton.extended(
                extendedIconLabelSpacing: _txTypeChipExtended ? 10 : 0,
                extendedPadding:
                    _txTypeChipExtended ? null : const EdgeInsets.all(16),
                onPressed: null,
                label: AnimatedSize(
                  duration: animDurationEmphasized,
                  curve: animCurveEmphasized,
                  child:
                      _txTypeChipExtended
                          ? Text(_transactionType.friendlyName(context))
                          : const SizedBox(),
                ),
                icon: Icon(_transactionType.verticalIcon),
                backgroundColor:
                    _savingInProgress
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : _transactionType.color,
              ),
            ),
          ],
        ),
      ),
    );
    childs.add(hDivider);

    childs.add(
      TransactionSectionCard(
        title: l10n.transactionSectionSplits,
        subtitle: l10n.transactionSectionSplitsSubtitle(_localAmounts.length),
        trailing: FilledButton.tonalIcon(
          onPressed:
              _savingInProgress
                  ? null
                  : () =>
                      _reconciled && _initiallyReconciled
                          ? null
                          : splitTransactionAdd(),
          icon: const Icon(Icons.call_split),
          label: Text(l10n.transactionSplitAdd),
        ),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < _localAmounts.length; i++) ...<Widget>[
              SizeTransition(
                sizeFactor: _cardsAnimation[i],
                axis: Axis.vertical,
                child: _buildSplitWidget(context, i),
              ),
              if (i != _localAmounts.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );

    return childs;
  }

  void checkAccountCurrency(AutocompleteAccount option, bool isSource) {
    // :TODO: ONLY ASSET ACCOUNTS HAVE A CURRENCY!

    // Update currency when:
    // 1. set account is source & assetAccount
    // 2. set account is destination & assetAccount & source account is NOT an
    //    asset account
    // 3. either source or destination account are still unset, so first to set
    if ((isSource &&
            (_sourceAccountType == AccountTypeProperty.assetAccount ||
                _sourceAccountType == AccountTypeProperty.debt)) ||
        (!isSource &&
            (_destinationAccountType == AccountTypeProperty.assetAccount ||
                _destinationAccountType == AccountTypeProperty.debt) &&
            (_sourceAccountType != AccountTypeProperty.assetAccount &&
                _sourceAccountType != AccountTypeProperty.debt)) ||
        (_sourceAccountType == AccountTypeProperty.swaggerGeneratedUnknown ||
            _destinationAccountType ==
                AccountTypeProperty.swaggerGeneratedUnknown)) {
      if (_localCurrency?.id != option.currencyId.toString()) {
        setState(() {
          _localCurrency = CurrencyRead(
            type: "currencies",
            id: option.currencyId.toString(),
            attributes: CurrencyProperties(
              code: option.currencyCode,
              name: option.currencyName,
              symbol: option.currencySymbol,
              decimalPlaces: option.currencyDecimalPlaces,
            ),
          );
        });
      }
    }
    // set foreign currency if account is destination & asset account and source
    // account is also asset account (transfer from one currency to other)
    if ((!isSource &&
            (_destinationAccountType == AccountTypeProperty.assetAccount ||
                _destinationAccountType == AccountTypeProperty.debt) &&
            (_sourceAccountType == AccountTypeProperty.assetAccount ||
                _destinationAccountType == AccountTypeProperty.debt)) &&
        _localCurrency?.id != option.currencyId) {
      // Only when destination & source account have different currency
      if (!_foreignCurrencies.every(
        (CurrencyRead? e) => e?.id == option.currencyId,
      )) {
        setState(() {
          _foreignCurrencies.fillRange(
            0,
            _foreignCurrencies.length,
            CurrencyRead(
              type: "currencies",
              id: option.currencyId,
              attributes: CurrencyProperties(
                code: option.currencyCode,
                name: option.currencyName,
                symbol: option.currencySymbol,
                decimalPlaces: option.currencyDecimalPlaces,
              ),
            ),
          );
        });
      }
    }
  }

  void checkTXType() {
    log.finest(() => "checkTXType()");

    TransactionTypeProperty txType = accountsToTransaction(
      _sourceAccountType,
      _destinationAccountType,
    );
    /* WATERFLY CUSTOM - NOT FIREFLY BEHAVIOR!
     * To ease UX, two assumptions:
     * 1. If only source is entered & it's an asset/liability account, it'll be
     *    a withdrawal
     * 2. If only destination is entered & it's an asset/liability account,
     *    it'll be a deposit
     *
     * As _ownAccountId will be set for both of these scenarios, the other one
     * would potentially be created by FF3 when saving. The actual webinterface
     * only does this when saving (but also throws an error when no ownAccount
     * is explicitly selected from the dropdown! Just typing the name [just as
     * in this app] will throw an error!).
     */

    if (txType == TransactionTypeProperty.swaggerGeneratedUnknown &&
        (_sourceAccountType == AccountTypeProperty.assetAccount ||
            _sourceAccountType == AccountTypeProperty.debt) &&
        _destinationAccountType ==
            AccountTypeProperty.swaggerGeneratedUnknown) {
      txType = TransactionTypeProperty.withdrawal;
    } else if (txType == TransactionTypeProperty.swaggerGeneratedUnknown &&
        _sourceAccountType == AccountTypeProperty.swaggerGeneratedUnknown &&
        (_destinationAccountType == AccountTypeProperty.assetAccount ||
            _destinationAccountType == AccountTypeProperty.debt)) {
      txType = TransactionTypeProperty.deposit;
    }

    // Withdrawal: splits have common source account
    // Deposit: splits have common destination account
    // Transfer: splits have common accounts for both
    if (txType == TransactionTypeProperty.withdrawal ||
        txType == TransactionTypeProperty.transfer) {
      for (TextEditingController e in _sourceAccountTextControllers) {
        e.text = _sourceAccountTextController.text;
      }
    }
    if (txType == TransactionTypeProperty.deposit ||
        txType == TransactionTypeProperty.transfer) {
      for (TextEditingController e in _destinationAccountTextControllers) {
        e.text = _destinationAccountTextController.text;
      }
    }

    if (_transactionType != txType) {
      setState(() {
        if (txType != TransactionTypeProperty.swaggerGeneratedUnknown) {
          _txTypeChipExtended = true;
          Future<void>.delayed(animDurationEmphasized * 3, () {
            setState(() {
              _txTypeChipExtended = false;
            });
          });
        }
        _transactionType = txType;
      });
    }
  }

  Card _buildSplitWidget(BuildContext context, int i) {
    const Widget hDivider = SizedBox(height: 16);

    CancelableOperation<Response<AutocompleteAccountArray>>? fetchOp;

    return Card(
      key: ValueKey<int>(i),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  // (Split) Transaction title
                  AnimatedHeight(
                    child:
                        _split
                            ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: TransactionTitle(
                                    textController: _titleTextControllers[i],
                                    focusNode: _titleFocusNodes[i],
                                    disabled: _savingInProgress,
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                  AnimatedHeight(
                    child: _split ? hDivider : const SizedBox.shrink(),
                  ),
                  // (Split) Source Account
                  AnimatedHeight(
                    child:
                        _showSourceAccountSelection
                            ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: AutoCompleteText<AutocompleteAccount>(
                                    disabled: _savingInProgress,
                                    labelText:
                                        S.of(context).generalSourceAccount,
                                    labelIcon: Icons.logout,
                                    textController:
                                        _sourceAccountTextControllers[i],
                                    focusNode: _sourceAccountFocusNodes[i],
                                    displayStringForOption:
                                        (AutocompleteAccount option) =>
                                            option.name,
                                    onChanged:
                                        (_) => splitTransactionCheckAccounts(),
                                    onSelected:
                                        (_) => splitTransactionCheckAccounts(),
                                    optionsBuilder: (
                                      TextEditingValue textEditingValue,
                                    ) async {
                                      try {
                                        unawaited(fetchOp?.cancel());

                                        final FireflyIii api =
                                            context.read<FireflyService>().api;
                                        fetchOp = CancelableOperation<
                                          Response<AutocompleteAccountArray>
                                        >.fromFuture(
                                          api.v1AutocompleteAccountsGet(
                                            query: textEditingValue.text,
                                            types: _destinationAccountType
                                                .allowedOpposingTypes(false),
                                          ),
                                        );
                                        final Response<
                                          AutocompleteAccountArray
                                        >?
                                        response =
                                            await fetchOp
                                                ?.valueOrCancellation();
                                        if (response == null) {
                                          // Cancelled
                                          return const Iterable<
                                            AutocompleteAccount
                                          >.empty();
                                        }
                                        apiThrowErrorIfEmpty(
                                          response,
                                          mounted ? context : null,
                                        );

                                        return response.body!;
                                      } catch (e, stackTrace) {
                                        log.severe(
                                          "Error while fetching autocomplete from API",
                                          e,
                                          stackTrace,
                                        );
                                        return const Iterable<
                                          AutocompleteAccount
                                        >.empty();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                  AnimatedHeight(
                    child:
                        _showSourceAccountSelection
                            ? hDivider
                            : const SizedBox.shrink(),
                  ),
                  // (Split) Destination Account
                  AnimatedHeight(
                    child:
                        _showDestinationAccountSelection
                            ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: AutoCompleteText<AutocompleteAccount>(
                                    disabled: _savingInProgress,
                                    labelText:
                                        S.of(context).generalDestinationAccount,
                                    labelIcon: Icons.login,
                                    textController:
                                        _destinationAccountTextControllers[i],
                                    focusNode: _destinationAccountFocusNodes[i],
                                    onChanged:
                                        (_) => splitTransactionCheckAccounts(),
                                    onSelected:
                                        (_) => splitTransactionCheckAccounts(),
                                    displayStringForOption:
                                        (AutocompleteAccount option) =>
                                            option.name,
                                    optionsBuilder: (
                                      TextEditingValue textEditingValue,
                                    ) async {
                                      try {
                                        final FireflyIii api =
                                            context.read<FireflyService>().api;
                                        fetchOp = CancelableOperation<
                                          Response<AutocompleteAccountArray>
                                        >.fromFuture(
                                          api.v1AutocompleteAccountsGet(
                                            query: textEditingValue.text,
                                            types: _sourceAccountType
                                                .allowedOpposingTypes(true),
                                          ),
                                        );
                                        final Response<
                                          AutocompleteAccountArray
                                        >?
                                        response =
                                            await fetchOp
                                                ?.valueOrCancellation();
                                        if (response == null) {
                                          // Cancelled
                                          return const Iterable<
                                            AutocompleteAccount
                                          >.empty();
                                        }
                                        apiThrowErrorIfEmpty(
                                          response,
                                          mounted ? context : null,
                                        );

                                        return response.body!;
                                      } catch (e, stackTrace) {
                                        log.severe(
                                          "Error while fetching autocomplete from API",
                                          e,
                                          stackTrace,
                                        );
                                        return const Iterable<
                                          AutocompleteAccount
                                        >.empty();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                  AnimatedHeight(
                    child:
                        _showDestinationAccountSelection
                            ? hDivider
                            : const SizedBox.shrink(),
                  ),
                  // Category (always)
                  TransactionCategory(
                    textController: _categoryTextControllers[i],
                    focusNode: _categoryFocusNodes[i],
                    disabled: _savingInProgress,
                  ),
                  hDivider,
                  // Budget (for withdrawals)
                  AnimatedHeight(
                    child:
                        (_transactionType == TransactionTypeProperty.withdrawal)
                            ? TransactionBudget(
                              textController: _budgetTextControllers[i],
                              focusNode: _budgetFocusNodes[i],
                              disabled: _savingInProgress,
                            )
                            : const SizedBox.shrink(),
                  ),
                  AnimatedHeight(
                    child:
                        (_transactionType == TransactionTypeProperty.withdrawal)
                            ? hDivider
                            : const SizedBox.shrink(),
                  ),
                  // (Split) Foreign Currency
                  AnimatedHeight(
                    child:
                        (_split || _foreignCurrencies[i] != null)
                            ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: NumberInput(
                                    icon:
                                        (_foreignCurrencies[i] != null)
                                            ? const Icon(
                                              Icons.currency_exchange,
                                            )
                                            : const Icon(Icons.monetization_on),
                                    controller:
                                        (_foreignCurrencies[i] != null)
                                            ? _foreignAmountTextControllers[i]
                                            : _localAmountTextControllers[i],
                                    hintText:
                                        _foreignCurrencies[i]?.zero() ??
                                        _localCurrency?.zero() ??
                                        NumberFormat.currency(
                                          decimalDigits: 2,
                                        ).format(0),
                                    decimals:
                                        _foreignCurrencies[i]
                                            ?.attributes
                                            .decimalPlaces ??
                                        _localCurrency
                                            ?.attributes
                                            .decimalPlaces ??
                                        2,
                                    prefixText:
                                        "${_foreignCurrencies[i]?.attributes.code ?? _localCurrency?.attributes.code} ",
                                    onChanged: (String string) {
                                      if (_foreignCurrencies[i] != null) {
                                        _foreignAmounts[i] =
                                            double.tryParse(string) ?? 0;
                                      } else {
                                        _localAmounts[i] =
                                            double.tryParse(string) ?? 0;
                                      }
                                      splitTransactionCalculateAmount();
                                    },
                                    disabled:
                                        _savingInProgress ||
                                        _reconciled && _initiallyReconciled,
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                  AnimatedHeight(
                    child:
                        (_split || _foreignCurrencies[i] != null)
                            ? hDivider
                            : const SizedBox.shrink(),
                  ),
                  // (Split) Local Currency (when foreign selected)
                  AnimatedHeight(
                    child:
                        (_split && _foreignCurrencies[i] != null)
                            ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: NumberInput(
                                    icon: const Icon(Icons.currency_exchange),
                                    controller: _localAmountTextControllers[i],
                                    hintText:
                                        _localCurrency?.zero() ??
                                        NumberFormat.currency(
                                          decimalDigits: 2,
                                        ).format(0),
                                    decimals:
                                        _localCurrency
                                            ?.attributes
                                            .decimalPlaces ??
                                        2,
                                    prefixText:
                                        "${_localCurrency?.attributes.code} ",
                                    onChanged: (String string) {
                                      _localAmounts[i] =
                                          double.tryParse(string) ?? 0;
                                      splitTransactionCalculateAmount();
                                    },
                                    disabled:
                                        _savingInProgress ||
                                        _reconciled && _initiallyReconciled,
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox.shrink(),
                  ),
                  AnimatedHeight(
                    child:
                        (_split && _foreignCurrencies[i] != null)
                            ? hDivider
                            : const SizedBox.shrink(),
                  ),
                  // Tags (always)
                  TransactionTags(
                    interactable: !_savingInProgress,
                    textController: _tagsTextControllers[i],
                    tagsController: _tags[i],
                  ),
                  // Note (always)
                  hDivider,
                  TransactionNote(
                    textController: _noteTextControllers[i],
                    disabled: _savingInProgress,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSize(
                  duration: animDurationStandard,
                  curve: animCurveStandard,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: <Widget>[
                      // Reconciled Button
                      IconButton(
                        icon: const Icon(Icons.done_outline),
                        isSelected: _reconciled,
                        selectedIcon: const Icon(Icons.done),
                        onPressed:
                            _savingInProgress
                                ? null
                                : () => setState(() {
                                  _reconciled = !_reconciled;
                                  _initiallyReconciled = false;
                                }),
                        tooltip: S.of(context).generalReconcile,
                      ),
                      hDivider,
                      // Bills Button
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        isSelected: _bills[i] != null,
                        selectedIcon: const Icon(Icons.event_available),
                        onPressed:
                            _savingInProgress
                                ? null
                                : () async {
                                  BillRead? newBill =
                                      await showDialog<BillRead>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder:
                                            (BuildContext context) =>
                                                BillDialog(
                                                  currentBill: _bills[i],
                                                ),
                                      );
                                  // Back button returns "null"
                                  if (newBill == null) {
                                    return;
                                  }
                                  // Delete bill returns id "0"
                                  if (newBill.id.isEmpty || newBill.id == "0") {
                                    newBill = null;
                                  }
                                  if (newBill != _bills[i]) {
                                    setState(() {
                                      _bills[i] = newBill;
                                    });
                                    _scheduleDraftSave();
                                  }
                                },
                        tooltip: S.of(context).transactionDialogBillTitle,
                      ),
                      hDivider,
                      // Foreign Currency Button
                      IconButton(
                        icon: const Icon(Icons.currency_exchange),
                        isSelected: _foreignCurrencies[i] != null,
                        onPressed:
                            _savingInProgress
                                ? null
                                : !(_reconciled && _initiallyReconciled)
                                ? () async {
                                  CurrencyRead? newCurrency =
                                      await showDialog<CurrencyRead>(
                                        context: context,
                                        builder:
                                            (BuildContext context) =>
                                                CurrencyDialog(
                                                  currentCurrency:
                                                      _foreignCurrencies[i] ??
                                                      _localCurrency!,
                                                ),
                                      );
                                  if (newCurrency == null) {
                                    return;
                                  }

                                  if (newCurrency.id == _localCurrency!.id) {
                                    newCurrency = null;
                                    _foreignAmounts[i] = 0;
                                    _foreignAmountTextControllers[i].text = "";
                                  }

                                  log.fine(
                                    () =>
                                        "adding foreign currency ${newCurrency?.id ?? "null"} for $i",
                                  );

                                  setState(() {
                                    _foreignCurrencies[i] = newCurrency;
                                  });
                                  _scheduleDraftSave();
                                }
                                : null,
                        tooltip:
                            (_split)
                                ? S.of(context).transactionSplitChangeCurrency
                                : null,
                      ),
                      // Piggy Bank Button
                      // Only on new TX (similar to Firefly webinterface)
                      if (_newTX) ...<Widget>[
                        hDivider,
                        IconButton(
                          icon: const Icon(Icons.savings_outlined),
                          isSelected: _piggy[i] != null,
                          selectedIcon: const Icon(Icons.savings),
                          onPressed:
                              _savingInProgress
                                  ? null
                                  : () async {
                                    PiggyBankRead? newPiggy =
                                        await showDialog<PiggyBankRead>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder:
                                              (BuildContext context) =>
                                                  PiggyDialog(
                                                    currentPiggy: _piggy[i],
                                                  ),
                                        );
                                    // Back button returns "null"
                                    if (newPiggy == null) {
                                      return;
                                    }
                                    // Delete piggy returns id "0"
                                    if (newPiggy.id.isEmpty ||
                                        newPiggy.id == "0") {
                                      newPiggy = null;
                                    }
                                    if (newPiggy != _piggy[i]) {
                                      setState(() {
                                        _piggy[i] = newPiggy;
                                      });
                                      _scheduleDraftSave();
                                    }
                                  },
                          tooltip: S.of(context).transactionDialogPiggyTitle,
                        ),
                        hDivider,
                        // (Split) Source Account Button (for deposits)
                        if (_split) ...<Widget>[
                          if (!_showSourceAccountSelection &&
                              _transactionType ==
                                  TransactionTypeProperty.deposit) ...<Widget>[
                            IconButton(
                              icon: const Icon(Icons.add_business),
                              onPressed:
                                  _savingInProgress
                                      ? null
                                      : _split &&
                                          !_showSourceAccountSelection &&
                                          _transactionType ==
                                              TransactionTypeProperty.deposit &&
                                          !(_reconciled && _initiallyReconciled)
                                      ? () {
                                        log.fine(
                                          () =>
                                              "adding separate source account for $i",
                                        );
                                        _sourceAccountTextControllers[i].text =
                                            "";
                                        setState(() {
                                          _showSourceAccountSelection = true;
                                        });
                                        _scheduleDraftSave();
                                      }
                                      : null,
                              tooltip:
                                  (_split)
                                      ? S
                                          .of(context)
                                          .transactionSplitChangeSourceAccount
                                      : null,
                            ),
                            hDivider,
                          ],
                          // (Split) Destination Account Button (for withdrawals)
                          if (!_showDestinationAccountSelection &&
                              _transactionType ==
                                  TransactionTypeProperty
                                      .withdrawal) ...<Widget>[
                            IconButton(
                              icon: const Icon(Icons.add_business),
                              onPressed:
                                  _savingInProgress
                                      ? null
                                      : _split &&
                                          !_showDestinationAccountSelection &&
                                          _transactionType ==
                                              TransactionTypeProperty
                                                  .withdrawal &&
                                          !(_reconciled && _initiallyReconciled)
                                      ? () {
                                        log.fine(
                                          () =>
                                              "adding separate destination account for $i",
                                        );
                                        _destinationAccountTextControllers[i]
                                            .text = "";
                                        setState(() {
                                          _showDestinationAccountSelection =
                                              true;
                                        });
                                        _scheduleDraftSave();
                                      }
                                      : null,
                              tooltip:
                                  (_split)
                                      ? S
                                          .of(context)
                                          .transactionSplitChangeDestinationAccount
                                      : null,
                            ),
                            hDivider,
                          ],
                          // Delete Split Button
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed:
                                _savingInProgress
                                    ? null
                                    : _split &&
                                        !(_reconciled && _initiallyReconciled)
                                    ? () {
                                      log.fine(() => "marking $i for deletion");
                                      _cardsAnimationController[i].reverse();
                                    }
                                    : null,
                            tooltip:
                                (_split)
                                    ? S.of(context).transactionSplitDelete
                                    : null,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionDeleteButton extends StatelessWidget {
  const TransactionDeleteButton({
    super.key,
    required this.transactionId,
    required this.disabled,
  });

  final String? transactionId;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete),
      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
      onPressed:
          disabled
              ? null
              : () async {
                final FireflyIii api = context.read<FireflyService>().api;
                final NavigatorState nav = Navigator.of(context);
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder:
                      (BuildContext context) => const DeletionConfirmDialog(),
                );
                if (!(ok ?? false)) {
                  return;
                }

                await api.v1TransactionsIdDelete(id: transactionId);
                nav.pop(true);
              },
    );
  }
}

class TransactionTitle extends StatelessWidget {
  const TransactionTitle({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.disabled,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Logger log = Logger("Pages.Transaction.Title");

    CancelableOperation<Response<AutocompleteTransactionArray>>? fetchOp;

    log.finest(() => "build()");
    return AutoCompleteText<String>(
      disabled: disabled,
      labelText: S.of(context).transactionFormLabelTitle,
      labelIcon: Icons.receipt_long,
      textController: textController,
      focusNode: focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        try {
          unawaited(fetchOp?.cancel());

          final FireflyIii api = context.read<FireflyService>().api;
          fetchOp = CancelableOperation<
            Response<AutocompleteTransactionArray>
          >.fromFuture(
            api.v1AutocompleteTransactionsGet(query: textEditingValue.text),
          );
          final Response<AutocompleteTransactionArray>? response =
              await fetchOp?.valueOrCancellation();
          if (response == null) {
            return const Iterable<String>.empty();
          }
          apiThrowErrorIfEmpty(response, context.mounted ? context : null);

          return response.body!.map((AutocompleteTransaction e) => e.name);
        } catch (e, stackTrace) {
          log.severe(
            "Error while fetching autocomplete from API",
            e,
            stackTrace,
          );
          return const Iterable<String>.empty();
        }
      },
    );
  }
}

class TransactionNote extends StatelessWidget {
  const TransactionNote({
    super.key,
    required this.textController,
    required this.disabled,
  });

  final TextEditingController textController;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Logger log = Logger("Pages.Transaction.Note");

    log.finest(() => "build()");
    return Row(
      children: <Widget>[
        Expanded(
          child: TextFormField(
            enabled: !disabled,
            controller: textController,
            maxLines: null,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: S.of(context).transactionFormLabelNotes,
              icon: const Icon(Icons.description),
              filled: disabled,
            ),
          ),
        ),
      ],
    );
  }
}

class TransactionCategory extends StatelessWidget {
  const TransactionCategory({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.disabled,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Logger log = Logger("Pages.Transaction.Category");

    CancelableOperation<Response<AutocompleteCategoryArray>>? fetchOp;

    log.finest(() => "build()");
    return Row(
      children: <Widget>[
        Expanded(
          child: AutoCompleteText<String>(
            disabled: disabled,
            labelText: S.of(context).generalCategory,
            labelIcon: Icons.assignment,
            textController: textController,
            focusNode: focusNode,
            optionsBuilder: (TextEditingValue textEditingValue) async {
              try {
                unawaited(fetchOp?.cancel());

                final FireflyIii api = context.read<FireflyService>().api;
                fetchOp = CancelableOperation<
                  Response<AutocompleteCategoryArray>
                >.fromFuture(
                  api.v1AutocompleteCategoriesGet(query: textEditingValue.text),
                );
                final Response<AutocompleteCategoryArray>? response =
                    await fetchOp?.valueOrCancellation();
                if (response == null) {
                  // Cancelled
                  return const Iterable<String>.empty();
                }
                apiThrowErrorIfEmpty(
                  response,
                  context.mounted ? context : null,
                );

                return response.body!.map((AutocompleteCategory e) => e.name);
              } catch (e, stackTrace) {
                log.severe(
                  "Error while fetching autocomplete from API",
                  e,
                  stackTrace,
                );
                return const Iterable<String>.empty();
              }
            },
          ),
        ),
      ],
    );
  }
}

class TransactionBudget extends StatefulWidget {
  const TransactionBudget({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.disabled,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final bool disabled;

  @override
  State<TransactionBudget> createState() => _TransactionBudgetState();
}

class _TransactionBudgetState extends State<TransactionBudget> {
  final Logger log = Logger("Pages.Transaction.Budget");

  // Initial string is empty, as we expect it to be ok
  // (either empty or loaded from db)
  String? _budgetId = "";

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(() async {
      if (widget.focusNode.hasFocus) {
        return;
      }
      if (widget.textController.text.isEmpty) {
        setState(() {
          _budgetId = "";
        });
        return;
      }
      try {
        final FireflyIii api = context.read<FireflyService>().api;
        final Response<AutocompleteBudgetArray> response = await api
            .v1AutocompleteBudgetsGet(query: widget.textController.text);
        apiThrowErrorIfEmpty(response, mounted ? context : null);

        if (response.body!.isEmpty ||
            (response.body!.length > 1 &&
                response.body!.first.name != widget.textController.text)) {
          setState(() {
            _budgetId = null;
          });
        } else {
          widget.textController.text = response.body!.first.name;
          setState(() {
            _budgetId = response.body!.first.id;
          });
        }
      } catch (e, stackTrace) {
        log.severe("Error while fetching autocomplete from API", e, stackTrace);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    CancelableOperation<Response<AutocompleteBudgetArray>>? fetchOp;

    log.finest(() => "build()");
    return Row(
      children: <Widget>[
        Expanded(
          child: AutoCompleteText<AutocompleteBudget>(
            disabled: widget.disabled,
            labelText: S.of(context).generalBudget,
            labelIcon: Icons.payments,
            textController: widget.textController,
            focusNode: widget.focusNode,
            errorText:
                _budgetId == null
                    ? S.of(context).transactionErrorInvalidBudget
                    : null,
            errorIconOnly: true,
            displayStringForOption: (AutocompleteBudget option) => option.name,
            onSelected: (AutocompleteBudget option) {
              setState(() {
                _budgetId = option.id;
              });
            },
            optionsBuilder: (TextEditingValue textEditingValue) async {
              try {
                unawaited(fetchOp?.cancel());

                final FireflyIii api = context.read<FireflyService>().api;
                fetchOp = CancelableOperation<
                  Response<AutocompleteBudgetArray>
                >.fromFuture(
                  api.v1AutocompleteBudgetsGet(query: textEditingValue.text),
                );
                final Response<AutocompleteBudgetArray>? response =
                    await fetchOp?.valueOrCancellation();
                if (response == null) {
                  // Cancelled
                  return const Iterable<AutocompleteBudget>.empty();
                }
                apiThrowErrorIfEmpty(response, mounted ? context : null);

                return response.body!;
              } catch (e, stackTrace) {
                log.severe(
                  "Error while fetching autocomplete from API",
                  e,
                  stackTrace,
                );
                return const Iterable<AutocompleteBudget>.empty();
              }
            },
          ),
        ),
      ],
    );
  }
}

enum SharedAttachmentReviewAction { accept, discard }

class SharedAttachmentReviewDialog extends StatelessWidget {
  const SharedAttachmentReviewDialog({super.key, required this.result});

  final SharedAttachmentValidationResult result;

  String _acceptedSubtitle(
    BuildContext context,
    SharedAttachmentCandidate candidate,
  ) {
    final List<String> parts = <String>[
      candidate.mimeType,
      filesize(candidate.size),
    ];
    if (candidate.isAppOwnedCopy) {
      parts.add(S.of(context).transactionSharedAttachmentsTemporaryCopy);
    }
    return parts.join(' • ');
  }

  String _rejectedReason(
    BuildContext context,
    RejectedSharedAttachment rejected,
  ) {
    final S l10n = S.of(context);
    switch (rejected.reason) {
      case RejectedSharedAttachmentReason.emptyValue:
        return l10n.transactionSharedAttachmentsRejectedEmpty;
      case RejectedSharedAttachmentReason.unsupportedType:
        return l10n.transactionSharedAttachmentsRejectedUnsupportedType;
      case RejectedSharedAttachmentReason.invalidOrigin:
        return l10n.transactionSharedAttachmentsRejectedOrigin;
      case RejectedSharedAttachmentReason.missingFile:
        return l10n.transactionSharedAttachmentsRejectedMissingFile;
      case RejectedSharedAttachmentReason.tooLarge:
        return l10n.transactionSharedAttachmentsRejectedTooLarge(
          filesize(maxInboundSharedAttachmentBytes),
        );
      case RejectedSharedAttachmentReason.overLimit:
        return l10n.transactionSharedAttachmentsRejectedLimit(
          maxInboundSharedAttachmentCount,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final S l10n = S.of(context);
    final List<Widget> content = <Widget>[
      Text(l10n.transactionSharedAttachmentsReviewBody),
    ];

    if (result.accepted.isNotEmpty) {
      content.add(const SizedBox(height: 16));
      content.add(
        Text(
          l10n.transactionSharedAttachmentsAcceptedTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
      content.add(const SizedBox(height: 8));
      content.addAll(
        result.accepted.map(
          (SharedAttachmentCandidate candidate) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(candidate.filename),
            subtitle: Text(_acceptedSubtitle(context, candidate)),
          ),
        ),
      );
    }

    if (result.rejected.isNotEmpty) {
      content.add(const SizedBox(height: 16));
      content.add(
        Text(
          l10n.transactionSharedAttachmentsRejectedTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
      content.add(const SizedBox(height: 8));
      content.addAll(
        result.rejected.map(
          (RejectedSharedAttachment rejected) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.block),
            title: Text(rejected.displayName),
            subtitle: Text(_rejectedReason(context, rejected)),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(l10n.transactionSharedAttachmentsReviewTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      ),
      actions:
          result.accepted.isNotEmpty
              ? <Widget>[
                TextButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(SharedAttachmentReviewAction.discard),
                  child: Text(l10n.transactionSharedAttachmentsDiscard),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(SharedAttachmentReviewAction.accept),
                  child: Text(l10n.transactionSharedAttachmentsAccept),
                ),
              ]
              : <Widget>[
                FilledButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pop(SharedAttachmentReviewAction.discard),
                  child: Text(l10n.transactionSharedAttachmentsClose),
                ),
              ],
    );
  }
}

class _TransactionEditorValidationCard extends StatelessWidget {
  const _TransactionEditorValidationCard({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    S.of(context).transactionSectionAttention,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...messages.map(
              (String message) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '- $message',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionSectionCard extends StatelessWidget {
  const TransactionSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class AttachmentButton extends StatefulWidget {
  final List<AttachmentRead>? attachments;
  final Future<void> Function() onPressed;
  final bool disabled;

  const AttachmentButton({
    super.key,
    required this.attachments,
    required this.onPressed,
    required this.disabled,
  });

  @override
  State<AttachmentButton> createState() => _AttachmentButtonState();
}

class _AttachmentButtonState extends State<AttachmentButton> {
  late bool _hasAttachments;

  @override
  void initState() {
    super.initState();

    _hasAttachments = widget.attachments?.isNotEmpty ?? false;
  }

  @override
  void didUpdateWidget(covariant AttachmentButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    _hasAttachments = widget.attachments?.isNotEmpty ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return badges.Badge(
      badgeContent: Text(
        widget.attachments?.length.toString() ?? "..",
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      showBadge: _hasAttachments,
      badgeStyle: badges.BadgeStyle(
        badgeColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      badgeAnimation: const badges.BadgeAnimation.scale(
        animationDuration: animDurationEmphasized,
        curve: animCurveEmphasized,
      ),
      child: MaterialIconButton(
        icon: Icons.attach_file,
        tooltip: S.of(context).transactionAttachments,
        onPressed: widget.disabled ? null : widget.onPressed,
      ),
    );
  }
}

class DateTimePicker extends StatefulWidget {
  const DateTimePicker({
    super.key,
    required this.initialDateTime,
    required this.onDateTimeChanged,
    required this.disabled,
  });

  final tz.TZDateTime initialDateTime;
  final ValueChanged<tz.TZDateTime> onDateTimeChanged;
  final bool disabled;

  @override
  State<DateTimePicker> createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<DateTimePicker> {
  late tz.TZDateTime _selectedDateTime;
  late TextEditingController _dateTextController;
  late TextEditingController _timeTextController;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.initialDateTime;
    _dateTextController = TextEditingController(
      text: DateFormat.yMMMd().format(_selectedDateTime),
    );
    _timeTextController = TextEditingController(
      text: DateFormat.Hm().format(_selectedDateTime),
    );
  }

  @override
  void dispose() {
    _dateTextController.dispose();
    _timeTextController.dispose();

    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      locale: Locale(
        Intl.defaultLocale!.split('_').first,
        Intl.defaultLocale!.split('_').last,
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDateTime = tz.TZDateTime.from(
        _selectedDateTime.copyWith(
          year: pickedDate.year,
          month: pickedDate.month,
          day: pickedDate.day,
        ),
        _selectedDateTime.location,
      );
      _dateTextController.text = DateFormat.yMMMd().format(_selectedDateTime);
      widget.onDateTimeChanged(_selectedDateTime);
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDateTime.getTimeOfDay(),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _selectedDateTime = _selectedDateTime.setTimeOfDay(pickedTime);
      _timeTextController.text = DateFormat.Hm().format(_selectedDateTime);
      widget.onDateTimeChanged(_selectedDateTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IntrinsicWidth(
          child: TextFormField(
            enabled: !widget.disabled,
            controller: _dateTextController,
            decoration: InputDecoration(
              //prefixIcon: Icon(Icons.calendar_month),
              border: const OutlineInputBorder(),
              filled: widget.disabled,
            ),
            readOnly: true,
            onTap: _pickDate,
          ),
        ),
        const SizedBox(width: 16),
        IntrinsicWidth(
          child: TextFormField(
            enabled: !widget.disabled,
            controller: _timeTextController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: widget.disabled,
            ),
            readOnly: true,
            onTap: _pickTime,
          ),
        ),
      ],
    );
  }
}
