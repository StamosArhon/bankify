import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/animations.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/pages/home/accounts/row.dart';
import 'package:bankify/pages/home/accounts/search.dart';
import 'package:bankify/pages/navigation.dart';
import 'package:bankify/services/accounts_service.dart';
import 'package:bankify/widgets/screen_state_view.dart';

final Logger log = Logger("Pages.Accounts");

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Logger log = Logger("Pages.Accounts.Page");

  @override
  void initState() {
    super.initState();

    _tabController = TabController(vsync: this, length: 4);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavPageElements>().appBarBottom = TabBar(
        isScrollable: true,
        controller: _tabController,
        tabAlignment: TabAlignment.start,
        tabs: <Tab>[
          Tab(text: S.of(context).accountsLabelAsset),
          Tab(text: S.of(context).accountsLabelExpense),
          Tab(text: S.of(context).accountsLabelRevenue),
          Tab(text: S.of(context).accountsLabelLiabilities),
        ],
      );

      context.read<NavPageElements>().appBarActions = <Widget>[
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: MaterialLocalizations.of(context).searchFieldLabel,
          onPressed: () {
            log.finest(() => "pressed search button");
            Navigator.of(context).push(
              PageRouteBuilder<Widget>(
                pageBuilder:
                    (BuildContext context, _, _) => AccountSearch(
                      type: _accountTypes[_tabController.index],
                    ),
                transitionDuration: animDurationEmphasizedDecelerate,
                reverseTransitionDuration: animDurationEmphasizedAccelerate,
                transitionsBuilder:
                    (
                      BuildContext context,
                      Animation<double> primaryAnimation,
                      Animation<double> secondaryAnimation,
                      Widget child,
                    ) => SharedAxisTransition(
                      animation: primaryAnimation,
                      secondaryAnimation: secondaryAnimation,
                      transitionType: SharedAxisTransitionType.horizontal,
                      child: child,
                    ),
              ),

              /*    CupertinoPageRoute<bool>(
                builder: (BuildContext context) => AccountSearch(
                  type: _accountTypes[_tabController.index],
                ),
                fullscreenDialog: false,
              ),*/
            );
          },
        ),
      ];

      // Call once to set fab/page actions
      _handleTabChange();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();

    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      log.finer(() => "_handleTabChange(${_tabController.index})");
    }
  }

  static const List<AccountTypeFilter> _accountTypes = <AccountTypeFilter>[
    AccountTypeFilter.asset,
    AccountTypeFilter.expense,
    AccountTypeFilter.revenue,
    AccountTypeFilter.liabilities,
  ];
  final List<Widget> _tabPages =
      _accountTypes
          .map<Widget>((AccountTypeFilter t) => AccountDetails(accountType: t))
          .toList();

  @override
  Widget build(BuildContext context) {
    log.fine(() => "build(tab: ${_tabController.index})");
    return TabBarView(controller: _tabController, children: _tabPages);
  }
}

class AccountDetails extends StatefulWidget {
  const AccountDetails({super.key, required this.accountType});

  final AccountTypeFilter accountType;

  @override
  State<AccountDetails> createState() => _AccountDetailsState();
}

class _AccountDetailsState extends State<AccountDetails>
    with AutomaticKeepAliveClientMixin {
  final int _numberOfItemsPerRequest = 50;
  PagingState<int, AccountRead> _pagingState = PagingState<int, AccountRead>();

  final Logger log = Logger("Pages.Accounts.Details");
  late final AccountsService _accountsService;

  @override
  void initState() {
    super.initState();
    _accountsService = AccountsService(context.read<FireflyService>().api);
  }

  Future<void> _fetchPage() async {
    if (_pagingState.isLoading) return;

    try {
      final int pageKey = (_pagingState.keys?.last ?? 0) + 1;
      log.finest(
        "Getting page $pageKey (${_pagingState.pages?.length} pages loaded)",
      );

      final AccountsPageResult page = await _accountsService.fetchPage(
        type: widget.accountType,
        page: pageKey,
        limit: _numberOfItemsPerRequest,
      );

      if (mounted) {
        setState(() {
          _pagingState = _pagingState.copyWith(
            pages: <List<AccountRead>>[...?_pagingState.pages, page.accounts],
            keys: <int>[...?_pagingState.keys, pageKey],
            hasNextPage: !page.isLastPage,
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.fine(() => "build()");

    return RefreshIndicator(
      onRefresh:
          () => Future<void>.sync(
            () => setState(() {
              _pagingState = _pagingState.reset();
            }),
          ),
      child: PagedListView<int, AccountRead>(
        state: _pagingState,
        fetchNextPage: _fetchPage,
        builderDelegate: PagedChildBuilderDelegate<AccountRead>(
          animateTransitions: true,
          transitionDuration: animDurationStandard,
          invisibleItemsThreshold: 10,
          firstPageProgressIndicatorBuilder:
              (BuildContext context) => ScreenStateView.loading(
                title: S.of(context).generalLoading,
                message: S.of(context).accountsEmptySubtitle,
              ),
          firstPageErrorIndicatorBuilder:
              (BuildContext context) => ScreenStateView(
                icon: Icons.error_outline,
                title: S.of(context).generalError,
                message: S.of(context).accountsEmptySubtitle,
                action: FilledButton(
                  onPressed: _fetchPage,
                  child: Text(S.of(context).generalRetry),
                ),
              ),
          noItemsFoundIndicatorBuilder:
              (BuildContext context) => ScreenStateView(
                icon: Icons.account_balance_wallet_outlined,
                title: S.of(context).generalNothingToShow,
                message: S.of(context).accountsEmptySubtitle,
              ),
          itemBuilder:
              (BuildContext context, AccountRead item, int index) =>
                  accountRowBuilder(
                    context,
                    item,
                    index,
                    () => setState(() {
                      _pagingState = _pagingState.reset();
                    }),
                  ),
        ),
      ),
    );
  }
}
