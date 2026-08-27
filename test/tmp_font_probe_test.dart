import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('probe fonts+prefs', () async {
    // ignore: avoid_print
    print('F1');
    final FontLoader loader = FontLoader('PlusJakartaSans');
    for (final String f in <String>['Regular', 'Bold']) {
      final File file = File('assets/fonts/Plus_Jakarta_Sans/PlusJakartaSans-$f.ttf');
      // ignore: avoid_print
      print('F2 $f exists=${file.existsSync()}');
      final Uint8List bytes = await file.readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
    // ignore: avoid_print
    print('F3 fonts loaded');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
    // ignore: avoid_print
    print('F4 prefs ok');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
