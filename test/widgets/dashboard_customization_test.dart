import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/pages/home/main/dashboard.dart';
import 'package:bankify/settings.dart';

class _FakeDashboardSettingsProvider extends SettingsProvider {
  List<DashboardCards> _order = List<DashboardCards>.from(
    DashboardCards.values,
  );
  final List<DashboardCards> _hidden = <DashboardCards>[DashboardCards.tags];

  @override
  List<DashboardCards> get dashboardOrder => _order;

  @override
  List<DashboardCards> get dashboardHidden => _hidden;

  @override
  Future<void> setDashboardOrder(List<DashboardCards> order) async {
    _order = List<DashboardCards>.from(order);
    notifyListeners();
  }

  @override
  Future<void> dashboardHideCard(DashboardCards card) async {
    if (_hidden.contains(card)) {
      return;
    }
    _hidden.add(card);
    notifyListeners();
  }

  @override
  Future<void> dashboardShowCard(DashboardCards card) async {
    _hidden.remove(card);
    notifyListeners();
  }

  @override
  Future<void> showAllDashboardCards() async {
    _hidden.clear();
    notifyListeners();
  }

  @override
  Future<void> resetDashboardCustomization() async {
    _order = List<DashboardCards>.from(DashboardCards.values);
    _hidden
      ..clear()
      ..add(DashboardCards.tags);
    notifyListeners();
  }
}

Widget _buildTestApp(Widget child, SettingsProvider settings) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings,
    child: MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('dashboard settings can show all cards and restore defaults', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    final _FakeDashboardSettingsProvider settings =
        _FakeDashboardSettingsProvider();

    await tester.pumpWidget(
      _buildTestApp(const DashboardSettingsPage(), settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visible cards: 7 of 8'), findsOneWidget);
    expect(find.textContaining('Current-month tag breakdown'), findsOneWidget);

    await tester.tap(find.text('Show all cards'));
    await tester.pumpAndSettle();

    expect(find.text('Visible cards: 8 of 8'), findsOneWidget);

    await tester.tap(find.text('Restore defaults'));
    await tester.pumpAndSettle();

    expect(find.text('Visible cards: 7 of 8'), findsOneWidget);
  });
}
