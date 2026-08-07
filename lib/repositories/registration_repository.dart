import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/registration_status_model.dart';

/// Registration steps 2–10 (JSON), step 9 media & step 11 verification
/// (multipart), step 12 privacy (PATCH), and the status sync endpoint.
class RegistrationRepository {
  RegistrationRepository(this._client);

  final ApiClient _client;

  /// Steps 2–8 and 10 — plain JSON payloads.
  Future<ApiEnvelope> submitStep(
    int step,
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) => _client.post(ApiEndpoints.registerStep(step), body: payload, cancelToken: cancelToken);

  /// Step 9 — profile media as multipart upload.
  Future<ApiEnvelope> submitMedia({
    required Map<String, String?> files,
    Map<String, List<String>> galleryFiles = const <String, List<String>>{},
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) => _client.multipart(
    ApiEndpoints.registerStep(9),
    files: files,
    arrayFiles: galleryFiles,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  /// Step 11 — verification (multipart: cnic_number, cnic_front, cnic_back, selfie).
  Future<ApiEnvelope> submitVerification({
    required String cnicNumber,
    required String cnicFrontPath,
    required String cnicBackPath,
    required String selfiePath,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) => _client.multipart(
    ApiEndpoints.verificationSubmit,
    fields: <String, dynamic>{'cnic_number': cnicNumber},
    files: <String, String?>{
      'cnic_front': cnicFrontPath,
      'cnic_back': cnicBackPath,
      'selfie': selfiePath,
    },
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  Future<ApiEnvelope> currentVerification() => _client.get(ApiEndpoints.verificationCurrent);

  /// Step 12 — privacy settings (documented as PATCH /profile/privacy).
  Future<ApiEnvelope> updatePrivacy(Map<String, dynamic> payload) =>
      _client.patch(ApiEndpoints.profilePrivacy, body: payload);

  /// Registration status — the source of truth for resume/navigation.
  Future<RegistrationStatusModel> status({CancelToken? cancelToken}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.registerStatus,
      cancelToken: cancelToken,
    );
    return RegistrationStatusModel.fromJson(res.dataMap);
  }
}
