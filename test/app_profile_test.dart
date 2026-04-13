import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/app_profile.dart';

void main() {
  test('AppProfile derives a stable id from host and credentials', () {
    final AppProfile first = AppProfile.fromCredentials(
      host: 'https://bankify.example.com',
      apiKey: 'secret-token',
    );
    final AppProfile second = AppProfile.fromCredentials(
      host: 'https://bankify.example.com',
      apiKey: 'secret-token',
    );
    final AppProfile different = AppProfile.fromCredentials(
      host: 'https://bankify.example.com',
      apiKey: 'different-token',
    );

    expect(first, second);
    expect(first.id, hasLength(24));
    expect(different.id, isNot(first.id));
  });
}
