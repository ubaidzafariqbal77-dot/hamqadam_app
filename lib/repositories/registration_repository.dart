import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/registration_status_model.dart';

/// The registration API.
///
/// The backend no longer keeps per-step state. The app walks the user through
/// all 18 steps locally and then submits everything at once:
///
/// 1. `POST /auth/register/complete` (public, JSON) → Sanctum token
/// 2. `POST /auth/register/request-otp` (bearer) → emails a 6-digit code
/// 3. `POST /auth/register/verify-otp` (bearer) → registration finalised
///
/// The step endpoints below are deprecated upstream; they are kept only so a
/// single profile section can still be re-saved after signup.
class RegistrationRepository {
  RegistrationRepository(this._client);

  final ApiClient _client;

  // ---- Complete registration + email OTP ------------------------------------

  /// Submits the whole 18-step payload as ONE JSON request (the documented
  /// `Content-Type: application/json` form — media travel as base64 strings, so
  /// there is nothing multipart left to send).
  ///
  /// Deliberately unauthenticated: a stale token from a previous session must
  /// not 401 the request that creates the account.
  Future<ApiEnvelope> submitComplete(
    Map<String, dynamic> payload, {
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) => _client.post(
    ApiEndpoints.registerComplete,
    body: payload,
    onProgress: onProgress,
    cancelToken: cancelToken,
    authenticated: false,
  );

  /// Emails the verification code. [email] is optional — the API falls back to
  /// the authenticated user's address.
  Future<ApiEnvelope> requestRegistrationOtp({String? email, CancelToken? cancelToken}) =>
      _client.post(
        ApiEndpoints.registerRequestOtp,
        body: <String, dynamic>{
          if (email != null && email.isNotEmpty) 'email': email,
        },
        cancelToken: cancelToken,
      );

  /// Confirms the emailed code and finalises the registration.
  Future<ApiEnvelope> verifyRegistrationOtp({
    required String code,
    String? email,
    CancelToken? cancelToken,
  }) => _client.post(
    ApiEndpoints.registerVerifyOtp,
    body: <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      'code': code,
    },
    cancelToken: cancelToken,
  );

  // ---- Deprecated step endpoints (post-signup section edits only) -----------

  /// Legacy step 1. Deliberately unauthenticated so a stale token from a
  /// previous session cannot 401 the request.
  Future<ApiEnvelope> submitStep1(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) => _client.post(
    ApiEndpoints.registerStep1,
    body: payload,
    cancelToken: cancelToken,
    authenticated: false,
  );

  /// Saves one section on its own (`POST /auth/register/step/{step}`), bearer
  /// token attached. Always the authenticated form — including step 1 — so
  /// re-saving a section after signup can never create a second account.
  Future<ApiEnvelope> submitStep(
    int apiStep,
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) => _client.post(
    ApiEndpoints.registerStep(apiStep),
    body: payload,
    cancelToken: cancelToken,
  );

  /// Steps 11 (photos) and 13 (identity documents) — `multipart/form-data`.
  Future<ApiEnvelope> submitStepMultipart(
    int apiStep, {
    Map<String, dynamic> fields = const <String, dynamic>{},
    Map<String, String?> files = const <String, String?>{},
    Map<String, List<String>> arrayFiles = const <String, List<String>>{},
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) => _client.multipart(
    ApiEndpoints.registerStep(apiStep),
    fields: fields,
    files: files,
    arrayFiles: arrayFiles,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  /// Flow metadata (`GET /auth/register/steps`).
  Future<ApiEnvelope> stepsMeta({CancelToken? cancelToken}) =>
      _client.get(ApiEndpoints.registerSteps, cancelToken: cancelToken);

  /// Registration status — drives resume and the completion percentage.
  Future<RegistrationStatusModel> status({CancelToken? cancelToken}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.registerStatus,
      cancelToken: cancelToken,
    );
    return RegistrationStatusModel.fromJson(res.dataMap);
  }

  // ---- Standalone verification (also usable after signup) -------------------

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

  /// Privacy settings (`PATCH /profile/privacy`).
  Future<ApiEnvelope> updatePrivacy(Map<String, dynamic> payload) =>
      _client.patch(ApiEndpoints.profilePrivacy, body: payload);
}
