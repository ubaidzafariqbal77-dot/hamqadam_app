import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/controllers/lookup_controller.dart';
import 'package:hamqadam/controllers/profile_controller.dart';
import 'package:hamqadam/core/api/api_client.dart';
import 'package:hamqadam/core/network/network_info.dart';
import 'package:hamqadam/core/storage/secure_storage_service.dart';
import 'package:hamqadam/repositories/lookup_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('probe', () async {
    // ignore: avoid_print
    print('P1');
    final ApiClient client = ApiClient(storage: SecureStorageService(), networkInfo: NetworkInfo());
    // ignore: avoid_print
    print('P2');
    final LookupController lookup = LookupController(LookupRepository(client));
    await lookup.preloadReference();
    // ignore: avoid_print
    print('P3 keys=${ProfileController.lookupKeysUsed.length}');
    for (final String key in ProfileController.lookupKeysUsed) {
      await lookup.ensure(key);
      // ignore: avoid_print
      print('P4 $key -> ${lookup.itemsOf(key).length}');
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
