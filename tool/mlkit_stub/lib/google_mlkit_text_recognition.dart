/// Native-free stand-in for `google_mlkit_text_recognition`.
///
/// Mirrors the real package's public API — the same class, enum and factory
/// names — so `lib/core/utils/cnic_ocr_service.dart` compiles against it
/// unchanged. Nothing here recognises text: [TextRecognizer.processImage] always
/// throws, which `CnicOcrService.extractCnic` already catches and turns into
/// "no number found", so the identity step falls back to typing the CNIC in by
/// hand instead of crashing.
///
/// Active only while `pubspec_overrides.yaml` points at it. Never ship a build
/// made with this package — card scanning silently stops working.
library;

import 'dart:io';
import 'dart:math' show Point;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

/// Why any call fails, worded so it is obvious in a log or a bug report.
const String _stubMessage =
    'ML Kit is not in this build: it was replaced by tool/mlkit_stub so the app '
    'could run on an arm64 iOS simulator. Text recognition is unavailable. '
    'Remove pubspec_overrides.yaml (tool/simulator.sh off) for a real build.';

/// Scripts the real recogniser supports.
enum TextRecognitionScript { latin, chinese, devanagiri, japanese, korean }

/// API-compatible recogniser that recognises nothing.
class TextRecognizer {
  TextRecognizer({this.script = TextRecognitionScript.latin}) {
    // Loud on creation, not just on use: a stubbed build should be impossible to
    // mistake for a working one while testing.
    if (kDebugMode) debugPrint('⚠️  $_stubMessage');
  }

  final TextRecognitionScript script;

  Future<RecognizedText> processImage(InputImage inputImage) async =>
      throw UnsupportedError(_stubMessage);

  Future<void> close() async {}
}

/// The real package's result type, kept so callers still type-check.
class RecognizedText {
  RecognizedText({required this.text, required this.blocks});

  final String text;
  final List<TextBlock> blocks;
}

class TextBlock {
  TextBlock({
    required this.text,
    required this.lines,
    required this.boundingBox,
    required this.recognizedLanguages,
    required this.cornerPoints,
  });

  final String text;
  final List<TextLine> lines;
  final Rect boundingBox;
  final List<String> recognizedLanguages;
  final List<Point<int>> cornerPoints;
}

class TextLine {
  TextLine({
    required this.text,
    required this.elements,
    required this.boundingBox,
    required this.recognizedLanguages,
    required this.cornerPoints,
  });

  final String text;
  final List<TextElement> elements;
  final Rect boundingBox;
  final List<String> recognizedLanguages;
  final List<Point<int>> cornerPoints;
}

class TextElement {
  TextElement({
    required this.text,
    required this.boundingBox,
    required this.cornerPoints,
  });

  final String text;
  final Rect boundingBox;
  final List<Point<int>> cornerPoints;
}

/// Stand-in for the `google_mlkit_commons` type the real package re-exports.
class InputImage {
  InputImage._({this.filePath, this.bytes});

  factory InputImage.fromFilePath(String path) => InputImage._(filePath: path);

  factory InputImage.fromFile(File file) => InputImage._(filePath: file.path);

  factory InputImage.fromBytes({
    required Uint8List bytes,
    required InputImageMetadata metadata,
  }) => InputImage._(bytes: bytes);

  final String? filePath;
  final Uint8List? bytes;
}

/// Present only so `InputImage.fromBytes` keeps the real signature.
class InputImageMetadata {
  const InputImageMetadata({
    required this.size,
    required this.rotation,
    required this.format,
    required this.bytesPerRow,
  });

  final Size size;
  final InputImageRotation rotation;
  final InputImageFormat format;
  final int bytesPerRow;
}

enum InputImageRotation { rotation0deg, rotation90deg, rotation180deg, rotation270deg }

enum InputImageFormat { nv21, yv12, yuv_420_888, yuv420, bgra8888 }
