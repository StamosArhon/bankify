import 'package:chopper/chopper.dart' show Response;
import 'package:bankify/app_profile.dart';
import 'package:bankify/auth.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:bankify/profile_cache_store.dart';

class AccountsPageResult {
  const AccountsPageResult({required this.accounts, required this.isLastPage});

  final List<AccountRead> accounts;
  final bool isLastPage;
}

class AccountsService {
  const AccountsService({
    required this.api,
    required this.profile,
    required this.cacheStore,
  });

  final FireflyIii api;
  final AppProfile profile;
  final ProfileCacheStore cacheStore;

  Future<AccountsPageResult> fetchPage({
    required AccountTypeFilter type,
    required int page,
    required int limit,
  }) async {
    final ProfileCachedLoader cachedLoader = ProfileCachedLoader(
      profile: profile,
      cacheStore: cacheStore,
    );
    final String cacheKey = "accounts:${type.name}:$page:$limit";
    final AccountArray accountArray = await cachedLoader.load<AccountArray>(
      key: cacheKey,
      fetch: () async {
        final Response<AccountArray> response = await api.v1AccountsGet(
          type: type,
          page: page,
        );
        apiThrowErrorIfEmpty(response, null);
        return response.body!;
      },
      encode: (AccountArray value) => value.toJson(),
      decode:
          (Object? json) =>
              AccountArray.fromJson(json! as Map<String, dynamic>),
    );

    final List<AccountRead> accounts = accountArray.data;
    return AccountsPageResult(
      accounts: accounts,
      isLastPage: accounts.length < limit,
    );
  }
}
