/// No-op stand-in for `google_mlkit_text_recognition`, active only when
/// swapped in via `dependency_overrides` in the app's pubspec.yaml.
///
/// The real plugin ships no arm64-simulator slice, and this Mac's Xcode
/// can no longer download an x86_64 fallback runtime, so the real plugin
/// can't be linked into an iOS Simulator build at all. This stub keeps
/// `CnicOcrService`'s import and public API resolving — with no native
/// iOS/Android code, so no CocoaPod is generated — but always reports "no
/// text found". Swap back to the real package (comment out the override)
/// for Android and real-device iOS builds, where OCR should actually run.
library;

enum TextRecognitionScript { latin, chinese, devanagari, japanese, korean }

class InputImage {
  InputImage._(this.filePath);

  final String? filePath;

  static InputImage fromFilePath(String path) => InputImage._(path);
}

class RecognizedText {
  const RecognizedText({required this.text});

  final String text;
}

class TextRecognizer {
  TextRecognizer({this.script = TextRecognitionScript.latin});

  final TextRecognitionScript script;

  Future<RecognizedText> processImage(InputImage inputImage) async =>
      const RecognizedText(text: '');

  Future<void> close() async {}
}
