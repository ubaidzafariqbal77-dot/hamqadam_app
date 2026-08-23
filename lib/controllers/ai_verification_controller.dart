import 'dart:async';

import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../models/ai_verification_model.dart';
import '../repositories/ai_verification_repository.dart';

/// Drives the AI identity-verification screen and the verification banner.
///
/// The check runs out of band after registration, so the flow is: read the
/// status, and while it is `pending` poll until it settles. The member can also
/// force a run, which is synchronous and takes a few seconds.
class AiVerificationController extends GetxController {
  AiVerificationController(this._repo);

  final AiVerificationRepository _repo;

  /// How often to re-read a `pending` status, and for how long. The model needs
  /// a few seconds per attempt; giving up after two minutes stops a stuck
  /// attempt polling forever in the background.
  static const Duration _pollInterval = Duration(seconds: 4);
  static const Duration _pollCeiling = Duration(minutes: 2);

  final Rx<ApiState<AiVerificationModel>> state = const ApiState<AiVerificationModel>.initial().obs;

  final Rx<ApiState<List<AiVerificationAttempt>>> history =
      const ApiState<List<AiVerificationAttempt>>.initial().obs;

  /// True only while a member-triggered run is in flight, so the button can
  /// show a spinner without the whole screen flipping to loading.
  final RxBool running = false.obs;

  /// Message from the last run, surfaced next to the button.
  final RxnString lastRunMessage = RxnString();

  Timer? _poll;
  DateTime? _pollStartedAt;

  AiVerificationModel? get status => state.value.data;
  bool get isVerified => status?.isApproved ?? false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
  }

  Future<void> load() async {
    state.value = const ApiState<AiVerificationModel>.loading();
    await _refresh(setLoading: false);
  }

  Future<void> reload() => _refresh(setLoading: false);

  Future<void> _refresh({bool setLoading = true}) async {
    if (setLoading) state.value = const ApiState<AiVerificationModel>.loading();
    try {
      final AiVerificationModel data = await _repo.fetchStatus();
      state.value = ApiState<AiVerificationModel>.success(data);
      // Only keep polling while the server still expects a verdict.
      if (data.isPending) {
        _startPolling();
      } else {
        _stopPolling();
      }
    } on AppException catch (e) {
      state.value = ApiState<AiVerificationModel>.fromException(e);
      _stopPolling();
    } catch (e) {
      state.value = ApiState<AiVerificationModel>.serverError(e.toString());
      _stopPolling();
    }
  }

  /// Runs the check now. Returns the outcome so the caller can route on it (the
  /// post-registration screen sends approved members onward and everyone else
  /// to the dashboard).
  ///
  /// A "not verified" answer is a normal 200, not an error — it is reported
  /// through the returned result, not thrown.
  Future<AiVerificationRunResult?> runNow() async {
    if (running.value) return null;
    running.value = true;
    lastRunMessage.value = null;
    try {
      final AiVerificationRunResult result = await _repo.run();
      lastRunMessage.value = result.message;
      // The run already updated the server state; reflect it without a second
      // spinner on the whole screen.
      await _refresh(setLoading: false);
      return result;
    } on AppException catch (e) {
      lastRunMessage.value = e.message;
      return null;
    } catch (e) {
      lastRunMessage.value = e.toString();
      return null;
    } finally {
      running.value = false;
    }
  }

  Future<void> loadHistory() async {
    history.value = const ApiState<List<AiVerificationAttempt>>.loading();
    try {
      final List<AiVerificationAttempt> rows = await _repo.fetchHistory();
      history.value = rows.isEmpty
          ? const ApiState<List<AiVerificationAttempt>>.empty(
              message: 'No verification attempts yet.',
            )
          : ApiState<List<AiVerificationAttempt>>.success(rows);
    } on AppException catch (e) {
      history.value = ApiState<List<AiVerificationAttempt>>.fromException(e);
    } catch (e) {
      history.value = ApiState<List<AiVerificationAttempt>>.serverError(e.toString());
    }
  }

  // ---- Polling --------------------------------------------------------------

  void _startPolling() {
    if (_poll != null) return;
    _pollStartedAt = DateTime.now();
    _poll = Timer.periodic(_pollInterval, (Timer _) {
      final DateTime? started = _pollStartedAt;
      if (started != null && DateTime.now().difference(started) > _pollCeiling) {
        _stopPolling();
        return;
      }
      _refresh(setLoading: false);
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
    _pollStartedAt = null;
  }
}
