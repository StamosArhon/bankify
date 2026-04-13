import 'package:chopper/chopper.dart' show Response;
import 'package:intl/intl.dart';
import 'package:bankify/app_profile.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/profile_cache_store.dart';

class BillsService {
  const BillsService({
    required this.api,
    required this.profile,
    required this.cacheStore,
  });

  final FireflyIii api;
  final AppProfile profile;
  final ProfileCacheStore cacheStore;

  Future<List<BillRead>> fetchBillsForDateWindow({
    required DateTime start,
    required DateTime end,
  }) async {
    final String startDate = DateFormat('yyyy-MM-dd', 'en_US').format(start);
    final String endDate = DateFormat('yyyy-MM-dd', 'en_US').format(end);
    final ProfileCachedLoader cachedLoader = ProfileCachedLoader(
      profile: profile,
      cacheStore: cacheStore,
    );
    final List<BillRead> bills = await cachedLoader.load<List<BillRead>>(
      key: "bills-window:$startDate:$endDate",
      fetch: () async {
        final Response<BillArray> response = await api.v1BillsGet(
          start: startDate,
          end: endDate,
        );
        apiThrowErrorIfEmpty(response, null);
        return response.body!.data;
      },
      encode:
          (List<BillRead> value) =>
              value.map((BillRead bill) => bill.toJson()).toList(),
      decode:
          (Object? json) =>
              (json! as List<dynamic>)
                  .map(
                    (dynamic item) =>
                        BillRead.fromJson(item as Map<String, dynamic>),
                  )
                  .toList(),
    );
    return bills;
  }

  Future<Map<String, List<BillRead>>> fetchCurrentPeriodBills({
    required bool showOnlyActiveBills,
    required bool showOnlyExpectedBills,
    required String ungroupedLabel,
  }) async {
    final DateTime start = DateTime.now().copyWith(day: 1);
    final DateTime end = start.copyWith(month: start.month + 1);
    final String startDate = DateFormat('yyyy-MM-dd', 'en_US').format(start);
    final String endDate = DateFormat('yyyy-MM-dd', 'en_US').format(end);
    final ProfileCachedLoader cachedLoader = ProfileCachedLoader(
      profile: profile,
      cacheStore: cacheStore,
    );
    final List<BillRead> bills = await cachedLoader.load<List<BillRead>>(
      key: "bills-current:$startDate:$endDate",
      fetch: () async {
        final List<BillRead> bills = <BillRead>[];
        late Response<BillArray> response;
        int pageNumber = 0;

        do {
          pageNumber += 1;
          response = await api.v1BillsGet(
            page: pageNumber,
            start: startDate,
            end: endDate,
          );
          apiThrowErrorIfEmpty(response, null);
          bills.addAll(response.body!.data);
        } while ((response.body!.meta.pagination?.currentPage ?? 1) <
            (response.body!.meta.pagination?.totalPages ?? 1));

        return bills;
      },
      encode:
          (List<BillRead> value) =>
              value.map((BillRead bill) => bill.toJson()).toList(),
      decode:
          (Object? json) =>
              (json! as List<dynamic>)
                  .map(
                    (dynamic item) =>
                        BillRead.fromJson(item as Map<String, dynamic>),
                  )
                  .toList(),
    );

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
