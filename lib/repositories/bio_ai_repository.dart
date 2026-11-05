import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../core/utils/app_logger.dart';

/// One generated bio from `POST /v1/bio/ai-generate`.
class BioAiResult {
  const BioAiResult({
    required this.text,
    required this.middle,
    required this.openingId,
    required this.closingId,
    required this.generationIndex,
  });

  /// Opening, middle and closing joined by blank lines — ready for the field.
  final String text;
  final String middle;
  final String openingId;
  final String closingId;
  final int generationIndex;

  factory BioAiResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> paragraphs =
        (json['paragraphs'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();
    return BioAiResult(
      text: (json['text'] ?? '').toString(),
      middle: (paragraphs['middle'] ?? '').toString(),
      openingId: (json['opening_id'] ?? '').toString(),
      closingId: (json['closing_id'] ?? '').toString(),
      generationIndex: (json['generation_index'] as num?)?.toInt() ?? 1,
    );
  }
}

/// A failure the user can act on, already worded for a snackbar.
class BioAiException implements Exception {
  const BioAiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Talks to the Hamqadam Bio AI service — a separate host from the main API,
/// so it has its own [Dio] rather than the backend [ApiClient].
///
/// The service is stateless for this call: the repository remembers which
/// templates and middle paragraphs it has already shown, and sends that back
/// so every "generate again" rotates the opening/closing and writes a
/// different middle (requirements §2.2).
class BioAiRepository {
  BioAiRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              // A real model call with retries can take a while.
              receiveTimeout: const Duration(seconds: 90),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  final List<String> _usedOpenings = <String>[];
  final List<String> _usedClosings = <String>[];
  final List<String> _middles = <String>[];
  int _generation = 0;

  /// Forget the rotation history (e.g. a new registration).
  void reset() {
    _usedOpenings.clear();
    _usedClosings.clear();
    _middles.clear();
    _generation = 0;
  }

  /// Generates a complete bio from [profile] (canonical, human-readable
  /// fields — see `AppProfile` in the service's OpenAPI). [maxChars] keeps the
  /// whole bio inside the text box.
  Future<BioAiResult> generate(
    Map<String, dynamic> profile, {
    int? maxChars,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'profile': profile,
      'generation_index': _generation + 1,
      if (maxChars != null) 'max_chars': maxChars,
      if (_usedOpenings.isNotEmpty) 'last_opening_id': _usedOpenings.last,
      if (_usedClosings.isNotEmpty) 'last_closing_id': _usedClosings.last,
      'used_opening_ids': _usedOpenings,
      'used_closing_ids': _usedClosings,
      'previous_middles': _middles.reversed.take(3).toList(),
    };
    try {
      final Response<dynamic> res = await _dio.post<dynamic>(
        '${ApiConfig.bioAiBaseUrl}/v1/bio/ai-generate',
        data: body,
        options: Options(
          headers: <String, String>{
            if (ApiConfig.bioAiAppKey.isNotEmpty)
              'X-App-Key': ApiConfig.bioAiAppKey,
          },
        ),
      );
      final BioAiResult result = BioAiResult.fromJson(
        (res.data as Map<dynamic, dynamic>).cast<String, dynamic>(),
      );
      _generation = result.generationIndex;
      _usedOpenings.add(result.openingId);
      _usedClosings.add(result.closingId);
      _middles.add(result.middle);
      return result;
    } on DioException catch (e) {
      AppLogger.w('Bio AI request failed: ${e.type} ${e.response?.statusCode}');
      throw _toException(e);
    }
  }

  static BioAiException _toException(DioException e) {
    final dynamic data = e.response?.data;
    final dynamic error = data is Map ? data['error'] : null;
    final String? code = error is Map ? error['code']?.toString() : null;
    switch (code) {
      case 'UNAUTHORIZED':
        // The build was made without bio_ai.env.json (no X-App-Key).
        AppLogger.e(
          'Bio AI rejected the app key - build with --dart-define-from-file=bio_ai.env.json',
        );
        return const BioAiException(
          'AI bio is not available in this version of the app. Please update the app.',
          code: 'UNAUTHORIZED',
        );
      case 'INSUFFICIENT_PROFILE_DATA':
        return const BioAiException(
          'Please complete your education or career details first, so the AI has something to write about.',
          code: 'INSUFFICIENT_PROFILE_DATA',
        );
      case 'RATE_LIMITED':
      case 'DAILY_LIMIT_REACHED':
        return BioAiException(
          'Too many requests. Please wait a moment and try again.',
          code: code,
        );
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const BioAiException(
        'Could not reach the AI service. Please check your connection.',
      );
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return const BioAiException(
        'The AI took too long to respond. Please try again.',
      );
    }
    final String? message = error is Map ? error['message']?.toString() : null;
    return BioAiException(
      message ?? 'Could not generate a bio right now. Please try again.',
      code: code,
    );
  }
}
