import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/verification_model.dart';

/// Document identity verification — `GET /verification/current`,
/// `GET /verification/history` and `POST /verification/submit`.
///
/// Separate from [AiVerificationRepository]: that one drives the automatic
/// pre-screen, this one drives the CNIC / selfie submission a human reviews.
/// Both feed the same badge, but only this one can produce a `verified` state.
class VerificationRepository {
  VerificationRepository(this._client);

  final ApiClient _client;

  /// The latest verification request, or [VerificationModel.none] when the
  /// member has never submitted.
  ///
  /// The server answers 200 with a null `data` in that case rather than 404, so
  /// an empty payload is a normal outcome and not an error.
  Future<VerificationModel> fetchCurrent({CancelToken? cancelToken}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.verificationCurrent,
      cancelToken: cancelToken,
    );
    final Map<String, dynamic> data = res.dataMap;
    if (data.isEmpty) return VerificationModel.none();
    return VerificationModel.fromJson(data);
  }

  /// Every past request, newest first (paginated at 20 server-side).
  Future<List<VerificationModel>> fetchHistory({CancelToken? cancelToken}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.verificationHistory,
      cancelToken: cancelToken,
    );

    // The endpoint paginates, so the rows arrive either as a bare list or
    // wrapped in `data`.
    final List<dynamic> rows = res.dataList.isNotEmpty
        ? res.dataList
        : (res.dataMap['data'] is List ? res.dataMap['data'] as List<dynamic> : <dynamic>[]);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(VerificationModel.fromJson)
        .toList(growable: false);
  }

  /// `POST /verification/submit` — CNIC front/back plus a selfie.
  ///
  /// The server rejects a second submission while one is still open (409
  /// `conflict`), so check [VerificationModel.canSubmit] first. Submitting also
  /// kicks off the AI face-match against the CNIC portrait out of band.
  Future<VerificationModel> submit({
    required String cnicNumber,
    required String cnicFrontPath,
    required String cnicBackPath,
    required String selfiePath,
    String? facePath,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final ApiEnvelope res = await _client.multipart(
      ApiEndpoints.verificationSubmit,
      fields: <String, dynamic>{'cnic_number': cnicNumber},
      files: <String, String?>{
        'cnic_front': cnicFrontPath,
        'cnic_back': cnicBackPath,
        'selfie': selfiePath,
        // Null paths are skipped by ApiClient.multipart.
        'face': facePath,
      },
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return VerificationModel.fromJson(res.dataMap);
  }
}
