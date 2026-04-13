import 'package:chopper/chopper.dart' show Response;
import 'package:bankify/auth.dart';
import 'package:bankify/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

class AccountsPageResult {
  const AccountsPageResult({required this.accounts, required this.isLastPage});

  final List<AccountRead> accounts;
  final bool isLastPage;
}

class AccountsService {
  const AccountsService(this.api);

  final FireflyIii api;

  Future<AccountsPageResult> fetchPage({
    required AccountTypeFilter type,
    required int page,
    required int limit,
  }) async {
    final Response<AccountArray> response = await api.v1AccountsGet(
      type: type,
      page: page,
    );
    apiThrowErrorIfEmpty(response, null);

    final List<AccountRead> accounts = response.body!.data;
    return AccountsPageResult(
      accounts: accounts,
      isLastPage: accounts.length < limit,
    );
  }
}
