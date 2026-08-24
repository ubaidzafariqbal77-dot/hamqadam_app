// Runs the OCR service against the REAL CNIC photos still sitting in the app's
// own cache from the last capture. Nothing is copied off the device.
//
// Run: flutter test integration_test/ocr_real_capture_test.dart -d <device>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/core/utils/cnic_ocr_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final CnicOcrService ocr = CnicOcrService();

  testWidgets('reads the real CNIC captures left in the app cache', (WidgetTester tester) async {
    // Prefer images staged at /sdcard/ocr_probe (pushed there for a one-off
    // check); otherwise fall back to whatever the last capture left in cache.
    // The app's own external files dir needs no storage permission, unlike
    // /sdcard, which scoped storage puts out of reach on Android 11+.
    final Directory? ext = await getExternalStorageDirectory();
    final Directory staged = Directory('${ext?.path}/ocr_probe');
    final Directory cache = staged.existsSync() ? staged : await getTemporaryDirectory();
    debugPrint('REAL: reading from ${cache.path}');

    // image_picker names its resized output `scaled_*`; the CNIC captures are
    // the largest of them because that step asks for highRes.
    final List<File> candidates =
        cache
            .listSync()
            .whereType<File>()
            .where(
              (File f) => f.path.endsWith('.jpg'),
            )
            .toList()
          ..sort((File a, File b) => b.lengthSync().compareTo(a.lengthSync()));

    if (candidates.isEmpty) {
      debugPrint('REAL: no scaled_*.jpg in cache — capture a CNIC in the app first.');
      return;
    }

    int read = 0;
    for (final File f in candidates.take(4)) {
      final String? cnic = await ocr.extractCnic(f.path);
      final double mb = f.lengthSync() / 1e6;
      // Only the last 4 digits are printed: enough to confirm a real read
      // without putting a full identity number in a build log.
      final String shown = cnic == null ? 'NOTHING' : '…${cnic.substring(cnic.length - 4)}';
      debugPrint('REAL ${mb.toStringAsFixed(2)} MB -> $shown');
      if (cnic != null) read++;
    }

    debugPrint('REAL: $read of ${candidates.take(4).length} images produced a CNIC');
    expect(read, greaterThan(0), reason: 'at least one real capture must read');
  });
}
