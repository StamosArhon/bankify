import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/animations.dart';
import 'package:bankify/app_session_state.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/pages/accounts.dart';
import 'package:bankify/pages/bills.dart';
import 'package:bankify/pages/categories.dart';
import 'package:bankify/pages/home.dart';
import 'package:bankify/pages/settings.dart';
import 'package:bankify/pages/transaction.dart';

final Logger log = Logger("Pages.Navigation");

class NavDestination {
  const NavDestination(
    this.label,
    this.pageHandler,
    this.icon,
    this.selectedIcon,
  );

  final String label;
  final Widget pageHandler;
  final Widget icon;
  final Widget selectedIcon;
}

class NavigationChromeController with ChangeNotifier {
  NavigationChromeController({required Widget title}) : _title = title;

  Widget _title;
  Widget get title => _title;
  Widget get appBarTitle => _title;
  set appBarTitle(Widget value) => setTitle(value);

  List<Widget>? _actions;
  List<Widget>? get actions => _actions;
  List<Widget>? get appBarActions => _actions;
  set appBarActions(List<Widget>? value) => setActions(value);

  PreferredSizeWidget? _bottom;
  PreferredSizeWidget? get bottom => _bottom;
  PreferredSizeWidget? get appBarBottom => _bottom;
  set appBarBottom(PreferredSizeWidget? value) => setBottom(value);

  Widget? _fab;
  Widget? get fab => _fab;
  set fab(Widget? value) => setFab(value);

  void setTitle(Widget title) {
    if (_title == title) {
      log.finer(() => "NavigationChromeController->setTitle equal, skipping");
      return;
    }
    _title = title;
    notifyListeners();
  }

  void setActions(List<Widget>? actions) {
    if (_actions == actions) {
      log.finer(() => "NavigationChromeController->setActions equal, skipping");
      return;
    }
    _actions = actions;
    notifyListeners();
  }

  void setBottom(PreferredSizeWidget? bottom) {
    if (_bottom == bottom) {
      log.finer(() => "NavigationChromeController->setBottom equal, skipping");
      return;
    }
    _bottom = bottom;
    notifyListeners();
  }

  void setFab(Widget? fab) {
    if (_fab == fab) {
      log.finer(() => "NavigationChromeController->setFab equal, skipping");
      return;
    }
    _fab = fab;
    notifyListeners();
  }

  void resetForDestination({required Widget title}) {
    _title = title;
    _actions = null;
    _bottom = null;
    _fab = null;
    notifyListeners();
  }
}

typedef NavPageElements = NavigationChromeController;

class NavPage extends StatefulWidget {
  const NavPage({
    super.key,
    this.initialLaunchRequest,
    this.onInitialLaunchHandled,
  });

  final AppLaunchRequest? initialLaunchRequest;
  final VoidCallback? onInitialLaunchHandled;

  @override
  State<NavPage> createState() => NavPageState();
}

class NavPageState extends State<NavPage> {
  final Logger log = Logger("Pages.Navigation.Page");

  int screenIndex = 0;
  late List<NavDestination> navDestinations;
  bool _handledInitialLaunch = false;
  NavigationChromeController? _chrome;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    navDestinations = <NavDestination>[
      NavDestination(
        S.of(context).navigationMain,
        const HomePage(),
        const Icon(Icons.dashboard_outlined),
        const Icon(Icons.dashboard),
      ),
      NavDestination(
        S.of(context).navigationAccounts,
        const AccountsPage(),
        const Icon(Icons.account_balance_outlined),
        const Icon(Icons.account_balance),
      ),
      NavDestination(
        S.of(context).navigationCategories,
        const CategoriesPage(),
        const Icon(Icons.assignment_outlined),
        const Icon(Icons.assignment),
      ),
      NavDestination(
        S.of(context).navigationBills,
        const BillsPage(),
        const Icon(Icons.receipt_outlined),
        const Icon(Icons.receipt),
      ),
      NavDestination(
        S.of(context).generalSettings,
        const SettingsPage(),
        const Icon(Icons.settings_outlined),
        const Icon(Icons.settings),
      ),
    ];

    _chrome ??= NavigationChromeController(
      title: Text(navDestinations[screenIndex].label),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeHandleInitialLaunch();
    });
  }

  @override
  void dispose() {
    _chrome?.dispose();
    super.dispose();
  }

  void _maybeHandleInitialLaunch() {
    if (_handledInitialLaunch || !mounted) {
      return;
    }
    final AppLaunchRequest? launchRequest = widget.initialLaunchRequest;
    if (!(launchRequest?.opensTransactionComposer ?? false)) {
      return;
    }

    _handledInitialLaunch = true;
    widget.onInitialLaunchHandled?.call();
    Navigator.of(context).push(
      MaterialPageRoute<Widget>(
        builder:
            (BuildContext context) => TransactionPage(
              notification: launchRequest?.notification,
              files: launchRequest?.sharedFiles,
            ),
      ),
    );
  }

  void _selectDestination(int index) {
    if (screenIndex == index) {
      return;
    }

    _chrome?.resetForDestination(title: Text(navDestinations[index].label));
    setState(() {
      screenIndex = index;
      _handledInitialLaunch = true;
    });
  }

  @override
  void didUpdateWidget(covariant NavPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialLaunchRequest != oldWidget.initialLaunchRequest) {
      if (widget.initialLaunchRequest?.opensTransactionComposer ?? false) {
        _handledInitialLaunch = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeHandleInitialLaunch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final NavDestination currentPage = navDestinations[screenIndex];
    log.finest(() => "nav build(page: $screenIndex)");

    return ChangeNotifierProvider<NavigationChromeController>.value(
      value: _chrome!,
      builder:
          (BuildContext context, _) => Scaffold(
            appBar: AppBar(
              title: context.select((NavigationChromeController n) => n.title),
              actions: context.select(
                (NavigationChromeController n) => n.actions,
              ),
              bottom: context.select(
                (NavigationChromeController n) => n.bottom,
              ),
            ),
            drawer: NavigationDrawer(
              selectedIndex: screenIndex,
              onDestinationSelected: (int index) {
                Navigator.pop(context); // closes the drawer
                _selectDestination(index);
              },
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: Text(
                    'Bankify',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...navDestinations.map((NavDestination destination) {
                  return NavigationDrawerDestination(
                    label: Text(destination.label),
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                  );
                }),
                const Divider(indent: 28, endIndent: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: GestureDetector(
                    onTap: () async {
                      final FireflyService ff = context.read<FireflyService>();
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder:
                            (BuildContext context) =>
                                const LogoutConfirmDialog(),
                      );
                      if (!(ok ?? false)) {
                        return;
                      }

                      await ff.signOut();
                    },
                    child: Text(
                      S.of(context).formButtonLogout,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 100),
              switchInCurve: animCurveStandard,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: Tween<double>(begin: 0, end: 1).animate(animation),
                  child: child,
                );
              },
              child: currentPage.pageHandler,
            ),
            floatingActionButton: context.select(
              (NavigationChromeController n) => n.fab,
            ),
          ),
    );
  }
}

class LogoutConfirmDialog extends StatelessWidget {
  const LogoutConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.logout),
      title: Text(S.of(context).formButtonLogout),
      clipBehavior: Clip.hardEdge,
      actions: <Widget>[
        TextButton(
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        FilledButton(
          child: Text(S.of(context).formButtonLogout),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
      content: Text(S.of(context).logoutConfirmation),
    );
  }
}
