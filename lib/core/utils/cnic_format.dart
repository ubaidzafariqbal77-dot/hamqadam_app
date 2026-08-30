/// CNIC number formatting and validation.
///
/// Pakistani CNIC numbers are `XXXXX-XXXXXXX-X` (5-7-1 digits). The number is
/// typed by the member; there is no OCR.
///
/// This used to be `CnicOcrService`, which read the number off the document
/// photo with on-device ML Kit. That was removed: the plugin ships no
/// arm64-simulator slice (so iOS Simulator builds needed a no-op stub, which
/// then silently disabled OCR wherever the stub leaked), and a misread number
/// was worse than no number at all. Manual entry is the whole flow now.
class CnicFormat {
  const CnicFormat._();

  /// True when [value] is a well-formed CNIC.
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
