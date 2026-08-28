/// Centralised list of every API endpoint used by the app.
///
/// Paths are relative to [ApiConfig.baseUrl] (which already ends in `/api/v1`).
class ApiEndpoints {
  const ApiEndpoints._();

  // ---- Auth -----------------------------------------------------------------
  static const String register = '/auth/register'; // legacy full-payload signup
  static const String loginEmail = '/auth/login/email';
  static const String requestMobileOtp = '/auth/otp/mobile';
  static const String loginMobile = '/auth/login/mobile';
  static const String loginGoogle = '/auth/login/google';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String deleteAccount = '/auth/account';

  // ---- Registration (single complete submission + email OTP) ----------------
  /// The whole 18-step payload in ONE `multipart/form-data` request. Public:
  /// it creates the draft account and returns the Sanctum token.
  static const String registerComplete = '/auth/register/complete';

  /// Emails a verification code to the freshly registered account (bearer).
  static const String registerRequestOtp = '/auth/register/request-otp';

  /// Confirms that code and finalises the registration (bearer).
  static const String registerVerifyOtp = '/auth/register/verify-otp';

  // ---- Step-wise registration (deprecated, kept for section edits) ----------
  /// Metadata for the whole flow (`GET`).
  static const String registerSteps = '/auth/register/steps';

  /// Server-authoritative progress (`GET`).
  static const String registerStatus = '/auth/register/status';

  /// The public legacy step 1 (creates a draft member). The app no longer calls
  /// it — registration goes through [registerComplete].
  static const String registerStep1 = '/auth/register/step1';

  /// Authenticated per-step save, used to re-save one profile section after
  /// signup. Step 1 uses this form too, so editing a section can never create a
  /// second account.
  static String registerStep(int step) => '/auth/register/step/$step';

  // ---- Verification ---------------------------------------------------------
  static const String verificationCurrent = '/verification/current';
  static const String verificationHistory = '/verification/history';
  static const String verificationSubmit = '/verification/submit';

  // ---- Profile / Privacy ----------------------------------------------------
  static const String profile = '/profile';
  static const String profilePrivacy = '/profile/privacy';
  static const String profileVisibility = '/profile/visibility';

  // ---- AI identity verification ---------------------------------------------
  /// Current AI verification state for the signed-in member. The app polls this
  /// after registration: the model runs out of band, so the registration
  /// response only reports `pending`.
  static const String aiVerificationStatus = '/verification/ai/status';

  /// Last 20 attempts, with which images were sent and why one failed.
  static const String aiVerificationHistory = '/verification/ai/history';

  /// Runs the check now. Takes NO uploads — the server rebuilds the model
  /// payload from the CNIC and selfie already stored at registration step 13,
  /// falling back to the profile photo. Synchronous and throttled to 3/min.
  static const String aiVerificationRun = '/verification/ai/run';

  // ---- Express interest ------------------------------------------------------
  /// Interests this member sent. `status` and `per_page` query params.
  static const String interestsSent = '/interests/sent';

  /// Interests received, plus `pending_count`.
  static const String interestsReceived = '/interests/received';

  /// Remaining coins and the cost per interest.
  static const String interestsCoinBalance = '/interests/coin-balance';

  /// Sends an interest. Costs coins; 402 `insufficient_coins` when short.
  static const String interests = '/interests';

  static String interestAccept(int id) => '/interests/$id/accept';
  static String interestReject(int id) => '/interests/$id/reject';

  /// Sender withdraws a pending interest. Coins are NOT refunded.
  static String interestWithdraw(int id) => '/interests/$id';

  // ---- Partner preferences ---------------------------------------------------
  /// The preferences captured at registration step 17. These drive match
  /// filtering server-side, so an empty set widens the pool rather than
  /// emptying it.
  static const String partnerPreferences = '/partner-preferences';

  // ---- Public profiles -------------------------------------------------------
  /// Another member's profile. Carries a verification BADGE only
  /// (`identity_verified`, `verified_at`) — never the owner's AI internals.
  static String publicProfile(int id) => '/profiles/$id';

  /// Compatibility score against another member.
  static String profileCompatibility(int id) => '/profiles/$id/compatibility';

  /// Deactivates the signed-in account.
  static const String profileDeactivate = '/profile/deactivate';

  // ---- Shortlists ------------------------------------------------------------
  /// Shortlisted proposals list (`GET /proposals/shortlists`) and create (`POST /proposals/shortlists`).
  static const String shortlists = '/proposals/shortlists';

  /// Check shortlist status (`GET /proposals/shortlists/{userId}/check`).
  static String shortlistCheck(int userId) => '/proposals/shortlists/$userId/check';

  /// Remove profile from shortlist (`DELETE /proposals/shortlists/{userId}`).
  static String shortlistRemove(int userId) => '/proposals/shortlists/$userId';

  // ---- Proposals ------------------------------------------------------------

  /// List proposals (`GET /proposals`) and send proposal (`POST /proposals`).
  static const String proposals = '/proposals';

  /// Accept proposal (`POST /proposals/{id}/accept`).
  static String proposalAccept(int id) => '/proposals/$id/accept';

  /// Reject proposal (`POST /proposals/{id}/reject`).
  static String proposalReject(int id) => '/proposals/$id/reject';

  /// Withdraw sent proposal (`POST /proposals/{id}/withdraw`).
  static String proposalWithdraw(int id) => '/proposals/$id/withdraw';

  /// Cancel proposal (`POST /proposals/{id}/cancel`).
  static String proposalCancel(int id) => '/proposals/$id/cancel';

  // ---- Profile Views --------------------------------------------------------


  /// Profiles viewed by the current authenticated user.
  static const String profileViews = '/profile-views';

  /// Members who viewed the current user's profile.
  static const String profileViewsReceived = '/profile-views/received';

  /// Current profile-view balance and active package info.
  static const String profileViewsBalance = '/profile-views/balance';

  /// Consumes one profile-view allowance and unlocks/returns the public profile.
  static String consumeProfileView(int profileId) => '/profile-views/$profileId';

  // ---- Dropdowns ------------------------------------------------------------
  /// Single endpoint that returns EVERY dropdown list (dynamic + hardcoded).
  static const String dropdownReferenceData = '/profile/dropdown-reference-data';

  // ---- Search / Discover ----------------------------------------------------
  /// Search and filter member profiles (`GET /search/profiles`).
  static const String searchProfiles = '/search/profiles';

  // ---- Chat -----------------------------------------------------------------
  /// List all conversation threads for the authenticated user.
  static const String chatThreads = '/chat/threads';

  /// Messages within a thread.
  static String chatMessages(int threadId) => '/chat/threads/$threadId/messages';

  /// Send a message to a thread.
  static String chatSend(int threadId) => '/chat/threads/$threadId/messages';

  /// Typing indicator.
  static String chatTyping(int threadId) => '/chat/threads/$threadId/typing';

  /// Block a thread.
  static String chatBlock(int threadId) => '/chat/threads/$threadId/block';

  /// Unblock a thread.
  static String chatUnblock(int threadId) => '/chat/threads/$threadId/unblock';

  /// Clear a thread (hides history from current user's side only).
  static String chatClear(int threadId) => '/chat/threads/$threadId/clear';

  /// Report a thread.
  static String chatReport(int threadId) => '/chat/threads/$threadId/report';

  /// Delete a single message (for the current user only).
  static String chatDeleteMessage(int messageId) => '/chat/messages/$messageId';

  // ---- Payments & Subscriptions ---------------------------------------------
  /// List of available membership plans (`GET /payments/plans`).
  static const String paymentPlans = '/payments/plans';

  /// Current active package and coin balance (`GET /payments/current`).
  static const String paymentCurrent = '/payments/current';

  /// Package details (`GET /payments/packages/{packageId}`).
  static String paymentPackage(int packageId) => '/payments/packages/$packageId';

  /// Feature usage breakdown (`GET /payments/usage`).
  static const String paymentUsage = '/payments/usage';

  /// Payment transaction history (`GET /payments/history`).
  static const String paymentHistory = '/payments/history';

  /// Payment invoice details (`GET /payments/invoices/{paymentId}`).
  static String paymentInvoice(int paymentId) => '/payments/invoices/$paymentId';

  /// Payment checkout initiation (`POST /payments/checkout`).
  static const String paymentCheckout = '/payments/checkout';

  /// Validate discount coupon (`POST /payments/coupons/validate`).
  static const String paymentValidateCoupon = '/payments/coupons/validate';

  // ---- Notifications --------------------------------------------------------
  /// List user notifications (`GET /notifications`).
  static const String notifications = '/notifications';

  /// Mark all notifications as read (`POST /notifications/mark-all-read`).
  static const String notificationsMarkAllRead = '/notifications/mark-all-read';

  /// Mark single notification as read (`POST /notifications/{id}/read`).
  static String notificationRead(int id) => '/notifications/$id/read';
}

