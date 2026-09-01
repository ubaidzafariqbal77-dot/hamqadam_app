import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/call_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/lookup_controller.dart';
import '../../controllers/ai_verification_controller.dart';
import '../../controllers/interest_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/partner_preference_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/profile_view_controller.dart';
import '../../controllers/proposal_controller.dart';
import '../../controllers/registration_controller.dart';
import '../../controllers/search_profiles_controller.dart';
import '../../controllers/shortlist_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/verification_controller.dart';
import '../../core/services/call_state_service.dart';
import '../../core/services/pusher_chat_service.dart';
import '../../core/utils/media_picker_helper.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/call_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/lookup_repository.dart';
import '../../repositories/ai_verification_repository.dart';
import '../../repositories/interest_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/partner_preference_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/profile_view_repository.dart';
import '../../repositories/proposal_repository.dart';
import '../../repositories/registration_repository.dart';
import '../../repositories/search_repository.dart';
import '../../repositories/shortlist_repository.dart';
import '../../repositories/auth_extra_repository.dart';
import '../../repositories/proposal_extra_repository.dart';
import '../../repositories/search_extra_repository.dart';
import '../../repositories/notification_extra_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/safety_repository.dart';
import '../../repositories/ai_helper_repository.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/family_repository.dart';
import '../../repositories/verification_repository.dart';

// New controllers
import '../../controllers/match_controller.dart';
import '../../controllers/safety_controller.dart';
import '../../controllers/search_extra_controller.dart';
import '../../controllers/proposal_extra_controller.dart';
import '../../controllers/notification_extra_controller.dart';
import '../../controllers/ai_helper_controller.dart';
import '../../controllers/content_controller.dart';
import '../../controllers/family_controller.dart';
import '../../controllers/auth_extra_controller.dart';
import '../../controllers/horoscope_controller.dart';
import '../../repositories/horoscope_repository.dart';
import '../../repositories/bridge_repository.dart';




import '../api/api_client.dart';
import '../network/network_info.dart';
import '../storage/current_user_service.dart';
import '../storage/profile_completion_service.dart';
import '../storage/registration_buffer.dart';
import '../storage/registration_draft_service.dart';
import '../storage/secure_storage_service.dart';

/// Central dependency wiring — called once from `main()`. Uses plain
/// `Get.put` registrations; deliberately NO `Bindings` classes anywhere.
///
/// App-lifetime singletons (services, repositories, session/lookup/registration
/// controllers) are registered here. Per-screen form controllers are created
/// and disposed by their own views via `Get.put` / `Get.delete`.
class AppDependencies {
  const AppDependencies._();

  static Future<void> init() async {
    // ---- Storage & platform ------------------------------------------------
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    Get.put<SharedPreferences>(prefs, permanent: true);

    final SecureStorageService secureStorage = SecureStorageService();
    await secureStorage.init(); // load cached token before first request
    Get.put<SecureStorageService>(secureStorage, permanent: true);

    Get.put<RegistrationDraftService>(RegistrationDraftService(prefs), permanent: true);
    Get.put<RegistrationBuffer>(RegistrationBuffer(prefs), permanent: true);
    Get.put<ProfileCompletionService>(ProfileCompletionService(prefs), permanent: true);
    Get.put<CurrentUserService>(CurrentUserService(prefs), permanent: true);
    Get.put<ThemeController>(ThemeController(prefs)..load(), permanent: true);
    Get.put<NetworkInfo>(NetworkInfo(), permanent: true);
    Get.put<MediaPickerHelper>(MediaPickerHelper(), permanent: true);

    // ---- Networking --------------------------------------------------------
    final ApiClient apiClient = ApiClient(
      storage: secureStorage,
      networkInfo: Get.find<NetworkInfo>(),
    );
    Get.put<ApiClient>(apiClient, permanent: true);

    // ---- Repositories ------------------------------------------------------
    Get.put<AuthRepository>(AuthRepository(apiClient), permanent: true);
    Get.put<RegistrationRepository>(RegistrationRepository(apiClient), permanent: true);
    Get.put<LookupRepository>(LookupRepository(apiClient), permanent: true);
    Get.put<ProfileRepository>(ProfileRepository(apiClient), permanent: true);
    Get.put<SearchRepository>(SearchRepository(apiClient), permanent: true);
    Get.put<AiVerificationRepository>(AiVerificationRepository(apiClient), permanent: true);
    Get.put<InterestRepository>(InterestRepository(apiClient), permanent: true);
    Get.put<PartnerPreferenceRepository>(PartnerPreferenceRepository(apiClient), permanent: true);
    Get.put<VerificationRepository>(VerificationRepository(apiClient), permanent: true);
    Get.put<ChatRepository>(ChatRepository(apiClient), permanent: true);
    Get.put<CallRepository>(CallRepository(apiClient), permanent: true);
    Get.put<ProfileViewRepository>(ProfileViewRepository(apiClient), permanent: true);
    Get.put<ShortlistRepository>(ShortlistRepository(apiClient), permanent: true);
    Get.put<PaymentRepository>(PaymentRepository(apiClient), permanent: true);
    Get.put<ProposalRepository>(ProposalRepository(apiClient), permanent: true);
    Get.put<NotificationRepository>(NotificationRepository(apiClient), permanent: true);

    // New repositories
    Get.put<MatchRepository>(MatchRepository(apiClient), permanent: true);
    Get.put<SafetyRepository>(SafetyRepository(apiClient), permanent: true);
    Get.put<SearchExtraRepository>(SearchExtraRepository(apiClient), permanent: true);
    Get.put<ProposalExtraRepository>(ProposalExtraRepository(apiClient), permanent: true);
    Get.put<NotificationExtraRepository>(NotificationExtraRepository(apiClient), permanent: true);
    Get.put<AiHelperRepository>(AiHelperRepository(apiClient), permanent: true);
    Get.put<ContentRepository>(ContentRepository(apiClient), permanent: true);
    Get.put<FamilyRepository>(FamilyRepository(apiClient), permanent: true);
    Get.put<AuthExtraRepository>(AuthExtraRepository(apiClient), permanent: true);
    Get.put<HoroscopeRepository>(HoroscopeRepository(apiClient), permanent: true);
    Get.put<BridgeRepository>(BridgeRepository(apiClient), permanent: true);



    final PusherChatService pusherService = PusherChatService(
      storage: secureStorage,
      bridgeRepository: Get.find<BridgeRepository>(),
    );
    Get.put<PusherChatService>(pusherService, permanent: true);

    // Call state service (tracks active calls, prevents duplicates)
    Get.put<CallStateService>(CallStateService.instance, permanent: true);

    // ---- Long-lived controllers -------------------------------------------
    final AuthController authController = AuthController(
      authRepository: Get.find<AuthRepository>(),
      storage: secureStorage,
      currentUser: Get.find<CurrentUserService>(),
    );
    Get.put<AuthController>(authController, permanent: true);

    // Centralised 401 handling (clears session, routes to login, no loops).
    apiClient.onUnauthorized = authController.handleUnauthorized;

    Get.put<LookupController>(LookupController(Get.find<LookupRepository>()), permanent: true);

    // Payment Controller (Permanent so plan/coin balances are accessible everywhere)
    Get.put<PaymentController>(
      PaymentController(Get.find<PaymentRepository>()),
      permanent: true,
    );

    // Shortlist Controller (Permanent so shortlist state is globally cached & synced)
    Get.put<ShortlistController>(
      ShortlistController(Get.find<ShortlistRepository>()),
      permanent: true,
    );

    // Proposal Controller (Permanent so proposal state and send/accept/reject is synced across app)
    Get.put<ProposalController>(
      ProposalController(
        Get.find<ProposalRepository>(),
        Get.find<CurrentUserService>(),
      ),
      permanent: true,
    );

    // Notification Controller (Permanent so unread badge count stays synced everywhere)
    Get.put<NotificationController>(
      NotificationController(Get.find<NotificationRepository>()),
      permanent: true,
    );

    // Discover / Search Controller
    Get.lazyPut<SearchProfilesController>(
      () => SearchProfilesController(
        repository: Get.find<SearchRepository>(),
        lookupController: Get.find<LookupController>(),
      ),
      fenix: true,
    );


    // Chat Controller
    // Permanent, not lazy: a call can arrive over Pusher at any moment, and the
    // controller that answers it must already exist — there is nobody to build
    // it on demand when the event lands.
    Get.put<CallController>(
      CallController(
        repository: Get.find<CallRepository>(),
        currentUser: Get.find<CurrentUserService>(),
      ),
      permanent: true,
    );

    // IMPORTANT: ChatController MUST be permanent (not lazy) because:
    // 1. Pusher user channel subscription happens in onInit() — needs to be alive
    //    from app start so calls/messages arrive on ANY screen.
    // 2. Pusher must NOT be disconnected when switching tabs.
    Get.put<ChatController>(
      ChatController(
        repository: Get.find<ChatRepository>(),
        pusher: Get.find<PusherChatService>(),
        currentUser: Get.find<CurrentUserService>(),
      ),
      permanent: true,
    );

    // Lazy: only fetches `/profile` when the Profile tab is first opened.
    // `fenix` recreates it if it is ever disposed, keeping the tab reusable.
    Get.lazyPut<ProfileController>(
      () => ProfileController(
        Get.find<ProfileRepository>(),
        Get.find<LookupController>(),
        Get.find<ProfileCompletionService>(),
      ),
      fenix: true,
    );
    // Lazy for the same reason as ProfileController: none of these should fire
    // a request until their screen is actually opened. `fenix` lets a disposed
    // controller be recreated, so the tabs stay reusable.
    Get.lazyPut<AiVerificationController>(
      () => AiVerificationController(Get.find<AiVerificationRepository>()),
      fenix: true,
    );
    Get.lazyPut<InterestController>(
      () => InterestController(Get.find<InterestRepository>()),
      fenix: true,
    );
    Get.lazyPut<PartnerPreferenceController>(
      () => PartnerPreferenceController(Get.find<PartnerPreferenceRepository>()),
      fenix: true,
    );
    Get.lazyPut<VerificationController>(
      () => VerificationController(Get.find<VerificationRepository>()),
      fenix: true,
    );
    Get.lazyPut<ProfileViewController>(
      () => ProfileViewController(Get.find<ProfileViewRepository>()),
      fenix: true,
    );

    Get.put<RegistrationController>(
      RegistrationController(
        buffer: Get.find<RegistrationBuffer>(),
        authRepository: Get.find<AuthRepository>(),
        registrationRepository: Get.find<RegistrationRepository>(),
        authController: authController,
        completion: Get.find<ProfileCompletionService>(),
      ),
      permanent: true,
    );

    // New controllers
    Get.put<SafetyController>(SafetyController(Get.find<SafetyRepository>()), permanent: true);
    Get.put<NotificationExtraController>(NotificationExtraController(Get.find<NotificationExtraRepository>()), permanent: true);
    Get.put<AiHelperController>(AiHelperController(Get.find<AiHelperRepository>()), permanent: true);
    Get.put<AuthExtraController>(AuthExtraController(Get.find<AuthExtraRepository>()), permanent: true);

    Get.lazyPut<MatchController>(() => MatchController(Get.find<MatchRepository>()), fenix: true);
    Get.lazyPut<SearchExtraController>(() => SearchExtraController(Get.find<SearchExtraRepository>()), fenix: true);
    Get.lazyPut<ProposalExtraController>(() => ProposalExtraController(Get.find<ProposalExtraRepository>()), fenix: true);
    Get.lazyPut<ContentController>(() => ContentController(Get.find<ContentRepository>()), fenix: true);
    Get.lazyPut<FamilyController>(() => FamilyController(Get.find<FamilyRepository>()), fenix: true);
    Get.lazyPut<HoroscopeController>(() => HoroscopeController(Get.find<HoroscopeRepository>()), fenix: true);

    // Restore any persisted session for the splash bootstrap.
    await authController.loadSession();
  }
}
