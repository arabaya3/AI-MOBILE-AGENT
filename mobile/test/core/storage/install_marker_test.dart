import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teia_ai/core/storage/token_store.dart';

void main() {
  test(
    'a token left by an earlier install is deleted on the first start',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = InMemoryTokenStore('old-install-token');
      await forgetTokenFromPreviousInstall(prefs, store);
      expect(await store.read(), isNull);
      expect(store.deleteCount, 1);
    },
  );

  test('later starts keep the signed-in session', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = InMemoryTokenStore();
    await forgetTokenFromPreviousInstall(prefs, store);
    await store.write('current-token');
    await forgetTokenFromPreviousInstall(prefs, store);
    expect(await store.read(), 'current-token');
    expect(store.deleteCount, 1);
  });
}
