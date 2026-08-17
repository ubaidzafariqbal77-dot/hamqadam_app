import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'app_logger.dart';

/// Extracts a Pakistani CNIC number from a document photo using on-device
/// ML Kit text recognition. Format: `XXXXX-XXXXXXX-X` (5-7-1 digits).
class CnicOcrService {
  /// Returns the normalised CNIC (`35202-1234567-1`) or null if none found.
  Future<String?> extractCnic(String imagePath) async {
    final TextRecognizer recognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final String? found = findCnic(result.text);
      if (found != null) {
        AppLogger.i('CNIC OCR read $found');
      } else {
        // Log what the recogniser actually saw — without this there is no way
        // to tell "no text at all" (bad photo/rotation) from "text read, but
        // the number did not match the pattern".
        final String seen = result.text.replaceAll('\n', ' | ');
        AppLogger.w(
          'CNIC OCR found no number. Recognised ${result.text.length} chars: '
          '${seen.length > 400 ? '${seen.substring(0, 400)}…' : seen}',
        );
      }
      return found;
    } catch (e) {
      AppLogger.w('CNIC OCR failed: $e');
      return null;
    } finally {
      await recognizer.close();
    }
  }

  /// Pulls a CNIC out of raw OCR text.
  ///
  /// Exposed for tests. Handles the three shapes OCR realistically returns:
  /// properly dashed, dashed with stray spaces (or en/em dashes substituted for
  /// the hyphen), and the dashes dropped entirely.
  static String? findCnic(String text) {
    // 5-7-1 with ANY 0-3 non-digits between the groups. ML Kit substitutes the
    // hyphen with en/em dashes, spaces, newlines, dots and stray glyphs
    // depending on the card's font and the photo angle, so matching a literal
    // '-' misses most real scans.
    final RegExpMatch? grouped =
        RegExp(r'(?<!\d)(\d{5})\D{0,3}(\d{7})\D{0,3}(\d)(?!\d)').firstMatch(text);
    if (grouped != null) {
      return '${grouped[1]}-${grouped[2]}-${grouped[3]}';
    }
    // Groups not distinguishable — fall back to any run of exactly 13 digits.
    for (final RegExpMatch m in RegExp(r'(?<!\d)[\d\s\-–—.]{13,20}(?!\d)').allMatches(text)) {
      final String digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 13) continue;
      return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
    }
    return null;
  }

  /// True when [value] is a well-formed CNIC, for the manual-entry field.
  static bool isValid(String value) =>
      RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(value.trim());

  /// Formats loose digits as `XXXXX-XXXXXXX-X` while the user types.
  static String format(String raw) {
    final String d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 5) return d;
    if (d.length <= 12) return '${d.substring(0, 5)}-${d.substring(5)}';
    return '${d.substring(0, 5)}-${d.substring(5, 12)}-${d.substring(12, d.length.clamp(12, 13))}';
  }
}
