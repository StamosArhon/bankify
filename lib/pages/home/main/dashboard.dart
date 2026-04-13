import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:bankify/generated/l10n/app_localizations.dart';
import 'package:bankify/settings.dart';

final Logger log = Logger("Pages.Home.Main.Dashboard");

class DashboardCardMetadata {
  const DashboardCardMetadata({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

DashboardCardMetadata dashboardCardMetadata(
  BuildContext context,
  DashboardCards card,
) {
  return switch (card) {
    DashboardCards.dailyavg => DashboardCardMetadata(
      title: S.of(context).homeMainChartDailyAvg,
      description: "Seven-day income and spending snapshot.",
      icon: Icons.today_outlined,
    ),
    DashboardCards.categories => DashboardCardMetadata(
      title: S.of(context).homeMainChartCategoriesTitle,
      description: "Current-month category breakdown.",
      icon: Icons.pie_chart_outline,
    ),
    DashboardCards.tags => DashboardCardMetadata(
      title: S.of(context).homeMainChartTagsTitle,
      description: "Current-month tag breakdown.",
      icon: Icons.sell_outlined,
    ),
    DashboardCards.accounts => DashboardCardMetadata(
      title: S.of(context).homeMainChartAccountsTitle,
      description: "Account balances and overview trends.",
      icon: Icons.account_balance_outlined,
    ),
    DashboardCards.netearnings => DashboardCardMetadata(
      title: S.of(context).homeMainChartNetEarningsTitle,
      description: "Monthly earned versus spent totals.",
      icon: Icons.trending_up_outlined,
    ),
    DashboardCards.networth => DashboardCardMetadata(
      title: S.of(context).homeMainChartNetWorthTitle,
      description: "Assets and liabilities over time.",
      icon: Icons.monitor_heart_outlined,
    ),
    DashboardCards.budgets => DashboardCardMetadata(
      title: S.of(context).homeMainBudgetTitle,
      description: "Budget usage and remaining limits.",
      icon: Icons.savings_outlined,
    ),
    DashboardCards.bills => DashboardCardMetadata(
      title: S.of(context).homeMainBillsTitle,
      description: "Upcoming bills and expected due dates.",
      icon: Icons.receipt_long_outlined,
    ),
  };
}

class DashboardSettingsPage extends StatefulWidget {
  const DashboardSettingsPage({super.key});

  @override
  State<DashboardSettingsPage> createState() => _DashboardSettingsPageState();
}

class _DashboardSettingsPageState extends State<DashboardSettingsPage> {
  final Logger log = Logger("Pages.Home.Main.Dashboard.Page");
  late List<DashboardCards> cards;

  @override
  void initState() {
    super.initState();
    cards =
        List<DashboardCards>.from(
          context.read<SettingsProvider>().dashboardOrder,
        ).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    log.finest("build()");

    final SettingsProvider settings = context.watch<SettingsProvider>();
    final List<DashboardCards> hiddenCards = List<DashboardCards>.from(
      settings.dashboardHidden,
    );
    final int visibleCount =
        cards
            .where((DashboardCards card) => !hiddenCards.contains(card))
            .length;

    Widget proxyDecorator(
      Widget child,
      int index,
      Animation<double> animation,
    ) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double animValue = Curves.easeInOut.transform(animation.value);
          final double elevation = lerpDouble(1, 6, animValue)!;
          final double scale = lerpDouble(1, 1.02, animValue)!;
          return Transform.scale(
            scale: scale,
            child: Card(elevation: elevation, child: child),
          );
        },
        child: child,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).homeMainDialogSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Visible cards: $visibleCount of ${cards.length}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Reorder cards to change the dashboard flow. Hidden cards stay in your saved order and can be shown again at any time.",
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed:
                            () =>
                                context
                                    .read<SettingsProvider>()
                                    .showAllDashboardCards(),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text("Show all cards"),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await context
                              .read<SettingsProvider>()
                              .resetDashboardCustomization();
                          setState(() {
                            cards = List<DashboardCards>.from(
                              context.read<SettingsProvider>().dashboardOrder,
                            );
                          });
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text("Restore defaults"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: cards.length,
            proxyDecorator: proxyDecorator,
            onReorder: (int oldIndex, int newIndex) async {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final DashboardCards item = cards.removeAt(oldIndex);
                cards.insert(newIndex, item);
              });
              await context.read<SettingsProvider>().setDashboardOrder(cards);
            },
            itemBuilder: (BuildContext context, int index) {
              return DashboardCardTile(
                key: ValueKey<DashboardCards>(cards[index]),
                card: cards[index],
                index: index,
                hidden: hiddenCards.contains(cards[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashboardCardTile extends StatelessWidget {
  const DashboardCardTile({
    super.key,
    required this.card,
    required this.index,
    required this.hidden,
  });

  final DashboardCards card;
  final int index;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final DashboardCardMetadata metadata = dashboardCardMetadata(context, card);

    return Opacity(
      opacity: hidden ? 0.65 : 1,
      child: Card(
        elevation: 0,
        child: ListTile(
          minTileHeight: 96,
          leading: CircleAvatar(child: Icon(metadata.icon)),
          title: Text(metadata.title),
          subtitle: Text(
            "${metadata.description}\n${hidden ? "Hidden from the home dashboard" : "Visible on the home dashboard"}",
            maxLines: 3,
          ),
          trailing: SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  selectedIcon: const Icon(Icons.visibility_off_outlined),
                  isSelected: hidden,
                  tooltip: hidden ? "Show card" : "Hide card",
                  onPressed:
                      () =>
                          hidden
                              ? context
                                  .read<SettingsProvider>()
                                  .dashboardShowCard(card)
                              : context
                                  .read<SettingsProvider>()
                                  .dashboardHideCard(card),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
