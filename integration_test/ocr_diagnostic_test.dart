// On-device diagnostic for CNIC text recognition.
//
// ML Kit only runs on a real device, so `flutter test` cannot tell us whether
// the recogniser works at all. This renders a synthetic card with a known CNIC,
// runs the real service against it, and prints exactly what the recogniser saw.
//
// Run: flutter test integration_test/ocr_diagnostic_test.dart -d <device>
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/core/utils/cnic_ocr_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Draws a card-like image with [cnic] on it and returns the PNG file path.
Future<String> _renderCard(String cnic, {required Size size, double fontSize = 64}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = const Color(0xFFF2F2F2),
  );

  void draw(String text, double x, double y, double fs, {FontWeight w = FontWeight.w700}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: const Color(0xFF111111), fontSize: fs, fontWeight: w),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  // Mimic the real card's layout closely enough to be representative.
  draw('ISLAMIC REPUBLIC OF PAKISTAN', 40, 30, fontSize * 0.42);
  draw('National Identity Card', 40, 30 + fontSize * 0.62, fontSize * 0.38, w: FontWeight.w400);
  draw('Name', 40, size.height * 0.32, fontSize * 0.36, w: FontWeight.w400);
  draw('Test Member', 40, size.height * 0.32 + fontSize * 0.5, fontSize * 0.52);
  draw('Identity Number', 40, size.height * 0.58, fontSize * 0.36, w: FontWeight.w400);
  draw(cnic, 40, size.height * 0.58 + fontSize * 0.5, fontSize);

  final ui.Image img = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
  final Directory dir = await getTemporaryDirectory();
  final File f = File('${dir.path}/ocr_probe_${size.width.toInt()}x${size.height.toInt()}.png');
  await f.writeAsBytes(png!.buffer.asUint8List());
  return f.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final CnicOcrService ocr = CnicOcrService();
  const String known = '35202-1234567-1';

  testWidgets('recogniser is alive on this device (large synthetic card)', (
    WidgetTester tester,
  ) async {
    final String path = await _renderCard(known, size: const Size(1600, 1000), fontSize: 72);
    final String? read = await ocr.extractCnic(path);
    debugPrint('PROBE large  -> ${read ?? "NOTHING"}');
    expect(
      read,
      known,
      reason: 'If this fails, ML Kit itself is not reading text on this device — '
          'the problem is not the photo.',
    );
  });

  testWidgets('portrait frame with a landscape card still reads', (WidgetTester tester) async {
    // The real captures are 2400x3200 portrait with the card horizontal inside.
    final String path = await _renderCard(known, size: const Size(1200, 1600), fontSize: 56);
    final String? read = await ocr.extractCnic(path);
    debugPrint('PROBE portrait -> ${read ?? "NOTHING"}');
    expect(read, known);
  });

  testWidgets('small text, as when the card fills little of the frame', (
    WidgetTester tester,
  ) async {
    // Approximates a card photographed from far away: the number ends up only
    // a couple of hundred pixels wide.
    final String path = await _renderCard(known, size: const Size(900, 1200), fontSize: 24);
    final String? read = await ocr.extractCnic(path);
    debugPrint('PROBE small    -> ${read ?? "NOTHING"}');
    // Not asserted: this is the case we expect to be marginal. The printed
    // result tells us whether resolution is the real limit.
  });
}
