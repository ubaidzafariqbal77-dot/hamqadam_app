import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_strings.dart';
import '../core/routes/app_routes.dart';
import '../core/services/permissions_service.dart';
import '../core/services/push_token_service.dart';
import '../core/storage/call_log_service.dart';
import '../core/services/pusher_chat_service.dart';
import '../core/storage/current_user_service.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../widgets/app_snackbar.dart';
import 'chat_controller.dart';
import 'lookup_controller.dart';
import 'notification_controller.dart';
import 'payment_controller.dart';
import 'proposal_controller.dart';
import 'registration_controller.dart';
import 'shortlist_controller.dart';

/// App-wide session state. The token is kept in secure storage; the current
/// user's full profile is kept locally in SharedPreferences via
/// [CurrentUserService]. Also centralises 401 handling (wired to [ApiClient]).
class AuthController extends GetxController {
  AuthController({
    required this.authRepository,
    required this.storage,
    required this.currentUser,
  });

  final AuthRepository authRepository;
  final SecureStorageService storage;
  final CurrentUserService currentUser;

  final Rxn<UserModel> user = Rxn<UserModel>();
  final RxBool isAuthenticated = false.obs;

  bool get hasToken => storage.hasToken;

  /// Loads any persisted session at startup (token from secure storage,
  /// user from SharedPreferences).
  Future<void> loadSession() async {
    user.value = currentUser.load();
    isAuthenticated.value = storage.hasToken;
    if (storage.hasToken) {
      _refreshAuthenticatedServices();
    }
  }

  /// Called after login / mobile OTP / registration: save token securely + full
  /// user in prefs.
  Future<void> persistSession(AuthResponseModel res) async {
    await storage.saveToken(res.token);
    if (res.user != null) {
      user.value = res.user;
      await currentUser.save(res.user!.raw); // full user JSON in SharedPreferences
    }
    isAuthenticated.value = true;
    AppLogger.i('Session persisted for user ${res.user?.id ?? '?'}');
    _refreshLookups();
    _refreshAuthenticatedServices();
  }

  /// `GET /profile/dropdown-reference-data` needs a bearer token, so every list
  /// warmed before this point is a bundled fallback with ids that do NOT match
  /// the server's. The moment a session exists, throw that away and refetch —
  /// otherwise the app keeps showing (and submitting) the wrong ids.
  void _refreshLookups() {
    if (!Get.isRegistered<LookupController>()) return;
    Get.find<LookupController>().preloadReference(force: true);
  }

  void _refreshAuthenticatedServices() {
    // Realtime first. Private channels are signed with the bearer token, so a
    // socket that came up before this point could not authorize anything — it
    // has to be told there is a session now.
    if (Get.isRegistered<PusherChatService>()) {
      final PusherChatService realtime = Get.find<PusherChatService>();
      realtime.ensureConnected();
      final int userId = user.value?.id ?? currentUser.user?.id ?? 0;
      if (userId > 0) realtime.subscribeToUserChannel(userId);
    }
    if (Get.isRegistered<ChatController>()) {
      Get.find<ChatController>().catchUp();
    }
    // A session is the only thing a device token can be attached to, so this is
    // the moment to register it — forced, because the previous member's
    // registration is not this member's.
    if (Get.isRegistered<PushTokenService>()) {
      Get.find<PushTokenService>().ensureSynced(force: true);
    }
    // Being battery-optimised is what lets the OEM cleaner force-stop the app,
    // and a force-stopped app receives no FCM at all - so a member who never
    // grants this will miss calls however correct everything else is. Asked
    // once, here rather than at first launch, so it is not the first thing a
    // new member sees.
    _requestCallReliabilityOnce();
    if (Get.isRegistered<PaymentController>()) {
      Get.find<PaymentController>().loadCurrentPackage(silent: true);
      Get.find<PaymentController>().loadPlans(silent: true);
    }
    if (Get.isRegistered<ShortlistController>()) {
      Get.find<ShortlistController>().loadShortlists(silent: true);
    }
    if (Get.isRegistered<ProposalController>()) {
      Get.find<ProposalController>().loadProposals(silent: true);
    }
    if (Get.isRegistered<NotificationController>()) {
      // The token itself is [PushTokenService]'s job now — it owns the retry
      // and the "already registered" bookkeeping, which this call site had no
      // way of knowing about.
      Get.find<NotificationController>().fetchNotifications(refresh: true);
      Get.find<NotificationController>().onSessionStarted();
    }
  }

  static const String _batteryPromptKey = 'asked_battery_exemption_v1';

  Future<void> _requestCallReliabilityOnce() async {
    if (!Get.isRegistered<SharedPreferences>()) return;
    final SharedPreferences prefs = Get.find<SharedPreferences>();
    final bool asked = prefs.getBool(_batteryPromptKey) ?? false;
    await PermissionsService.instance
        .requestCallReliability(alreadyAsked: asked);
    if (!asked) await prefs.setBool(_batteryPromptKey, true);
  }

  void _resetAuthenticatedServices() {
    // Drop the socket and its channels: the next member must not inherit this
    // one's `App.User.{id}` subscription and start receiving their calls.
    if (Get.isRegistered<PusherChatService>()) {
      Get.find<PusherChatService>().disconnect();
    }
    if (Get.isRegistered<ChatController>()) {
      Get.find<ChatController>().reset();
    }
    if (Get.isRegistered<PushTokenService>()) {
      Get.find<PushTokenService>().forgetSync();
    }
    // The call history is this member's, not the device's.
    if (Get.isRegistered<CallLogService>()) {
      Get.find<CallLogService>().clear();
    }
    if (Get.isRegistered<PaymentController>()) {
      Get.find<PaymentController>().reset();
    }
    if (Get.isRegistered<ShortlistController>()) {
      Get.find<ShortlistController>().reset();
    }
    if (Get.isRegistered<ProposalController>()) {
      Get.find<ProposalController>().reset();
    }
    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().reset();
    }
  }

  /// Invoked by the API client on HTTP 401. Clears the session but preserves
  /// registration drafts, then routes to login once (no redirect loops).
  Future<void> handleUnauthorized() async {
    if (Get.isRegistered<NotificationController>()) {
      await Get.find<NotificationController>().deletePushToken();
    }
    await storage.clearSession();
    await currentUser.clear();
    _resetAuthenticatedServices();
    isAuthenticated.value = false;
    user.value = null;
    if (Get.currentRoute != AppRoutes.login) {
      AppSnackbar.error(AppStrings.unauthorizedMessage);
      Get.offAllNamed(AppRoutes.login);
    }
  }


  Future<void> logout() async {
    try {
      await authRepository.logout();
    } catch (e) {
      AppLogger.w('Logout API failed (ignored): $e');
    }
    await _clearAndGoLogin();
  }

  /// Logs out from every device/session.
  Future<void> logoutAllDevices() async {
    try {
      await authRepository.logoutAll();
    } catch (e) {
      AppLogger.w('Logout-all API failed (ignored): $e');
    }
    await _clearAndGoLogin();
  }

  /// Deactivates the account then clears the session.
  Future<bool> deactivateAccount() async {
    try {
      await authRepository.deactivateAccount();
      await _clearAndGoLogin();
      return true;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    }
  }

  /// Refreshes the cached user from `/auth/me`.
  Future<void> refreshUser() async {
    try {
      final UserModel? fresh = await authRepository.me();
      if (fresh != null) {
        user.value = fresh;
        await currentUser.save(fresh.raw);
      }
    } on AppException catch (e) {
      AppLogger.w('refreshUser failed (ignored): $e');
    }
  }

  Future<void> _clearAndGoLogin() async {
    if (Get.isRegistered<NotificationController>()) {
      await Get.find<NotificationController>().deletePushToken();
    }
    await storage.clearSession();
    await currentUser.clear();
    _resetAuthenticatedServices();

    // Explicit logout / deactivation also drops the registration draft and the
    // profile-completion record so the next account starts from a clean slate.
    if (Get.isRegistered<RegistrationController>()) {
      await Get.find<RegistrationController>().resetForNewAccount();
    }
    isAuthenticated.value = false;
    user.value = null;
    Get.offAllNamed(AppRoutes.login);
  }
}
