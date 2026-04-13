import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/services/bills_service.dart';

BillRead _bill({
  required String id,
  required String name,
  required bool active,
  String? objectGroupTitle,
  int? objectGroupOrder,
  DateTime? nextExpectedMatch,
  List<BillProperties$PaidDates$Item>? paidDates,
}) {
  return BillRead(
    type: 'bills',
    id: id,
    attributes: BillProperties(
      name: name,
      active: active,
      objectGroupTitle: objectGroupTitle,
      objectGroupOrder: objectGroupOrder,
      paidDates: paidDates,
      nextExpectedMatch: nextExpectedMatch,
    ),
  );
}

void main() {
  group('BillsService.groupBills', () {
    test('groups by object group title and falls back to ungrouped label', () {
      final Map<String, List<BillRead>> grouped = BillsService.groupBills(
        bills: <BillRead>[
          _bill(
            id: '2',
            name: 'Phone',
            active: true,
            objectGroupTitle: null,
            objectGroupOrder: 2,
            paidDates: const <BillProperties$PaidDates$Item>[],
          ),
          _bill(
            id: '1',
            name: 'Rent',
            active: true,
            objectGroupTitle: 'Home',
            objectGroupOrder: 1,
            paidDates: const <BillProperties$PaidDates$Item>[],
          ),
        ],
        showOnlyActiveBills: false,
        showOnlyExpectedBills: false,
        ungroupedLabel: 'Ungrouped',
      );

      expect(grouped.keys, <String>['Home', 'Ungrouped']);
      expect(grouped['Home']!.single.id, '1');
      expect(grouped['Ungrouped']!.single.id, '2');
    });

    test('filters inactive and not-expected bills when requested', () {
      final Map<String, List<BillRead>> grouped = BillsService.groupBills(
        bills: <BillRead>[
          _bill(
            id: 'active-expected',
            name: 'Rent',
            active: true,
            objectGroupTitle: 'Home',
            nextExpectedMatch: DateTime.utc(2026, 4, 18),
            paidDates: const <BillProperties$PaidDates$Item>[],
          ),
          _bill(
            id: 'active-not-expected',
            name: 'Streaming',
            active: true,
            objectGroupTitle: 'Subscriptions',
            paidDates: const <BillProperties$PaidDates$Item>[],
          ),
          _bill(
            id: 'inactive',
            name: 'Old bill',
            active: false,
            objectGroupTitle: 'Legacy',
            paidDates: const <BillProperties$PaidDates$Item>[],
          ),
        ],
        showOnlyActiveBills: true,
        showOnlyExpectedBills: true,
        ungroupedLabel: 'Ungrouped',
      );

      expect(grouped.keys, <String>['Home']);
      expect(grouped['Home']!.single.id, 'active-expected');
    });
  });
}
