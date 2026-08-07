// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'app_logger.dart';

// TEMP: google_mlkit_text_recognition/google_mlkit_commons have no
// arm64-simulator slice and this toolchain has no x86_64 simulator runtime
// to fall back to, so the app can't launch in Simulator while this is wired
// up. Stubbed to unblock Simulator testing — restore the MLKit import and
// body above for real-device builds where OCR is needed.
/// Extracts a Pakistani CNIC number from a document photo using on-device
/// ML Kit text recognition. Format: `XXXXX-XXXXXXX-X` (5-7-1 digits).
class CnicOcrService {
  /// Returns the normalised CNIC (`35202-1234567-1`) or null if none found.
  Future<String?> extractCnic(String imagePath) async {
    AppLogger.w('CNIC OCR disabled (MLKit stubbed out for Simulator run)');
    return null;
  }
}
