import 'package:chopper/chopper.dart' show Response;
import 'package:intl/intl.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

class BillsService {
  const BillsService(this.api);

  final FireflyIii api;

  Future<List<BillRead>> fetchBillsForDateWindow({
    required DateTime start,
    required DateTime end,
  }) async {
    final Response<BillArray> response = await api.v1BillsGet(
      start: DateFormat('yyyy-MM-dd', 'en_US').format(start),
      end: DateFormat('yyyy-MM-dd', 'en_US').format(end),
    );
    apiThrowErrorIfEmpty(response, null);
    return response.body!.data;
  }

  Future<Map<String, List<BillRead>>> fetchCurrentPeriodBills({
    required bool showOnlyActiveBills,
    required bool showOnlyExpectedBills,
    required String ungroupedLabel,
  }) async {
    final DateTime start = DateTime.now().copyWith(day: 1);
    final DateTime end = start.copyWith(month: start.month + 1);
    final List<BillRead> bills = <BillRead>[];
    late Response<BillArray> response;
    int pageNumber = 0;

    do {
      pageNumber += 1;
      response = await api.v1BillsGet(
        page: pageNumber,
        start: DateFormat('yyyy-MM-dd', 'en_US').format(start),
        end: DateFormat('yyyy-MM-dd', 'en_US').format(end),
      );
      apiThrowErrorIfEmpty(response, null);
      bills.addAll(response.body!.data);
    } while ((response.body!.meta.pagination?.currentPage ?? 1) <
        (response.body!.meta.pagination?.totalPages ?? 1));

    return groupBills(
      bills: bills,
      showOnlyActiveBills: showOnlyActiveBills,
      showOnlyExpectedBills: showOnlyExpectedBills,
      ungroupedLabel: ungroupedLabel,
    );
  }

  static Map<String, List<BillRead>> groupBills({
    required List<BillRead> bills,
    required bool showOnlyActiveBills,
    required bool showOnlyExpectedBills,
    required String ungroupedLabel,
  }) {
    bills.sort(
      (BillRead a, BillRead b) => (a.attributes.objectGroupOrder ?? 0)
          .compareTo(b.attributes.objectGroupOrder ?? 0),
    );

    final Map<String, List<BillRead>> billsMap = <String, List<BillRead>>{};
    for (final BillRead bill in bills) {
      if (showOnlyActiveBills && !(bill.attributes.active ?? true)) {
        continue;
      }

      if (showOnlyExpectedBills &&
          bill.attributes.nextExpectedMatch == null &&
          bill.attributes.paidDates!.isEmpty) {
        continue;
      }

      final String key = bill.attributes.objectGroupTitle ?? ungroupedLabel;
      billsMap.putIfAbsent(key, () => <BillRead>[]).add(bill);
    }

    return billsMap;
  }
}
